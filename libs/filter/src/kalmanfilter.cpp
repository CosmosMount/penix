#include "kalmanfilter.hpp"

#include <cstdlib>
#include <cstring>

namespace filter
{

extern "C" __attribute__((weak)) void* kalman_platform_alloc(std::size_t size)
{
    return std::malloc(size);
}

void* kalmanfilter::allocate(size_t size)
{
    return kalman_platform_alloc(size);
}

kalmanfilter::kalmanfilter(uint8_t state_size, uint8_t control_size, uint8_t measurement_size)
    : state_size_(state_size), control_size_(control_size), measurement_size_(measurement_size)
{
    measurement_valid_num_ = 0;

    measurement_map_ = static_cast<uint8_t*>(allocate(sizeof(uint8_t) * measurement_size_));
    std::memset(measurement_map_, 0, sizeof(uint8_t) * measurement_size_);
    measurement_degree_ = static_cast<float*>(allocate(sizeof(float) * measurement_size_));
    std::memset(measurement_degree_, 0, sizeof(float) * measurement_size_);
    mat_r_diagonal_elements_ = static_cast<float*>(allocate(sizeof(float) * measurement_size_));
    std::memset(mat_r_diagonal_elements_, 0, sizeof(float) * measurement_size_);
    state_min_variance_ = static_cast<float*>(allocate(sizeof(float) * state_size_));
    std::memset(state_min_variance_, 0, sizeof(float) * state_size_);
    temp_ = static_cast<uint8_t*>(allocate(sizeof(uint8_t) * measurement_size_));
    std::memset(temp_, 0, sizeof(uint8_t) * measurement_size_);

    filtered_value_ = static_cast<float*>(allocate(sizeof(float) * state_size_));
    std::memset(filtered_value_, 0, sizeof(float) * state_size_);
    measured_vector_ = static_cast<float*>(allocate(sizeof(float) * measurement_size_));
    std::memset(measured_vector_, 0, sizeof(float) * measurement_size_);
    control_vector_ = static_cast<float*>(allocate(sizeof(float) * control_size_));
    std::memset(control_vector_, 0, sizeof(float) * control_size_);

    x_hat_data_ = static_cast<float*>(allocate(sizeof(float) * state_size_));
    std::memset(x_hat_data_, 0, sizeof(float) * state_size_);
    arm_mat_init_f32(&x_hat_, state_size_, 1, x_hat_data_);

    x_hat_minus_data_ = static_cast<float*>(allocate(sizeof(float) * state_size_));
    std::memset(x_hat_minus_data_, 0, sizeof(float) * state_size_);
    arm_mat_init_f32(&x_hat_minus_, state_size_, 1, x_hat_minus_data_);

    if (control_size_ != 0U)
    {
        control_data_ = static_cast<float*>(allocate(sizeof(float) * control_size_));
        std::memset(control_data_, 0, sizeof(float) * control_size_);
        arm_mat_init_f32(&control_, control_size_, 1, control_data_);
    }

    measurement_data_ = static_cast<float*>(allocate(sizeof(float) * measurement_size_));
    std::memset(measurement_data_, 0, sizeof(float) * measurement_size_);
    arm_mat_init_f32(&measurement_, measurement_size_, 1, measurement_data_);

    p_data_ = static_cast<float*>(allocate(sizeof(float) * state_size_ * state_size_));
    std::memset(p_data_, 0, sizeof(float) * state_size_ * state_size_);
    arm_mat_init_f32(&p_, state_size_, state_size_, p_data_);

    p_minus_data_ = static_cast<float*>(allocate(sizeof(float) * state_size_ * state_size_));
    std::memset(p_minus_data_, 0, sizeof(float) * state_size_ * state_size_);
    arm_mat_init_f32(&p_minus_, state_size_, state_size_, p_minus_data_);

    f_data_ = static_cast<float*>(allocate(sizeof(float) * state_size_ * state_size_));
    f_t_data_ = static_cast<float*>(allocate(sizeof(float) * state_size_ * state_size_));
    std::memset(f_data_, 0, sizeof(float) * state_size_ * state_size_);
    std::memset(f_t_data_, 0, sizeof(float) * state_size_ * state_size_);
    arm_mat_init_f32(&f_, state_size_, state_size_, f_data_);
    arm_mat_init_f32(&f_t_, state_size_, state_size_, f_t_data_);

    if (control_size_ != 0U)
    {
        b_data_ = static_cast<float*>(allocate(sizeof(float) * state_size_ * control_size_));
        std::memset(b_data_, 0, sizeof(float) * state_size_ * control_size_);
        arm_mat_init_f32(&b_, state_size_, control_size_, b_data_);
    }

    h_data_ = static_cast<float*>(allocate(sizeof(float) * measurement_size_ * state_size_));
    h_t_data_ = static_cast<float*>(allocate(sizeof(float) * state_size_ * measurement_size_));
    std::memset(h_data_, 0, sizeof(float) * measurement_size_ * state_size_);
    std::memset(h_t_data_, 0, sizeof(float) * state_size_ * measurement_size_);
    arm_mat_init_f32(&h_, measurement_size_, state_size_, h_data_);
    arm_mat_init_f32(&h_t_, state_size_, measurement_size_, h_t_data_);

    q_data_ = static_cast<float*>(allocate(sizeof(float) * state_size_ * state_size_));
    std::memset(q_data_, 0, sizeof(float) * state_size_ * state_size_);
    arm_mat_init_f32(&q_, state_size_, state_size_, q_data_);

    r_data_ = static_cast<float*>(allocate(sizeof(float) * measurement_size_ * measurement_size_));
    std::memset(r_data_, 0, sizeof(float) * measurement_size_ * measurement_size_);
    arm_mat_init_f32(&r_, measurement_size_, measurement_size_, r_data_);

    k_data_ = static_cast<float*>(allocate(sizeof(float) * state_size_ * measurement_size_));
    std::memset(k_data_, 0, sizeof(float) * state_size_ * measurement_size_);
    arm_mat_init_f32(&k_, state_size_, measurement_size_, k_data_);

    s_data_ = static_cast<float*>(allocate(sizeof(float) * state_size_ * state_size_));
    uint16_t max_dim_sq = (state_size_ > measurement_size_)
                              ? static_cast<uint16_t>(state_size_ * state_size_)
                              : static_cast<uint16_t>(measurement_size_ * measurement_size_);
    if (state_size_ * measurement_size_ > max_dim_sq)
    {
        max_dim_sq = static_cast<uint16_t>(state_size_ * measurement_size_);
    }
    temp_matrix_data_ = static_cast<float*>(allocate(sizeof(float) * max_dim_sq));
    temp_matrix_data1_ = static_cast<float*>(allocate(sizeof(float) * max_dim_sq));
    temp_vector_data_ = static_cast<float*>(allocate(sizeof(float) * state_size_));
    temp_vector_data1_ = static_cast<float*>(allocate(sizeof(float) * state_size_));

    arm_mat_init_f32(&s_, state_size_, state_size_, s_data_);
    arm_mat_init_f32(&temp_matrix_, state_size_, state_size_, temp_matrix_data_);
    arm_mat_init_f32(&temp_matrix1_, state_size_, state_size_, temp_matrix_data1_);
    arm_mat_init_f32(&temp_vector_, state_size_, 1, temp_vector_data_);
    arm_mat_init_f32(&temp_vector1_, state_size_, 1, temp_vector_data1_);
}

void kalmanfilter::measure()
{
    if (use_auto_adjustment_)
    {
        adjust_hkr();
        return;
    }

    std::memcpy(measurement_data_, measured_vector_, sizeof(float) * measurement_size_);
    std::memset(measured_vector_, 0, sizeof(float) * measurement_size_);
    if (control_size_ > 0U && control_data_ != nullptr)
    {
        std::memcpy(control_data_, control_vector_, sizeof(float) * control_size_);
    }
}

void kalmanfilter::update_x_hat_minus()
{
    if (control_size_ > 0U)
    {
        temp_vector_.numRows = state_size_;
        temp_vector_.numCols = 1;
        arm_mat_mult_f32(&f_, &x_hat_, &temp_vector_);
        temp_vector1_.numRows = state_size_;
        temp_vector1_.numCols = 1;
        arm_mat_mult_f32(&b_, &control_, &temp_vector1_);
        arm_mat_add_f32(&temp_vector_, &temp_vector1_, &x_hat_minus_);
        return;
    }
    arm_mat_mult_f32(&f_, &x_hat_, &x_hat_minus_);
}

void kalmanfilter::update_p_minus()
{
    arm_mat_trans_f32(&f_, &f_t_);
    arm_mat_mult_f32(&f_, &p_, &p_minus_);
    temp_matrix_.numRows = p_minus_.numRows;
    temp_matrix_.numCols = f_t_.numCols;
    arm_mat_mult_f32(&p_minus_, &f_t_, &temp_matrix_);
    arm_mat_add_f32(&temp_matrix_, &q_, &p_minus_);
}

void kalmanfilter::update_k()
{
    arm_mat_trans_f32(&h_, &h_t_);
    temp_matrix_.numRows = h_.numRows;
    temp_matrix_.numCols = p_minus_.numCols;
    arm_mat_mult_f32(&h_, &p_minus_, &temp_matrix_);
    temp_matrix1_.numRows = temp_matrix_.numRows;
    temp_matrix1_.numCols = h_t_.numCols;
    arm_mat_mult_f32(&temp_matrix_, &h_t_, &temp_matrix1_);
    s_.numRows = r_.numRows;
    s_.numCols = r_.numCols;
    arm_mat_add_f32(&temp_matrix1_, &r_, &s_);
    arm_mat_inverse_f32(&s_, &temp_matrix1_);
    temp_matrix_.numRows = p_minus_.numRows;
    temp_matrix_.numCols = h_t_.numCols;
    arm_mat_mult_f32(&p_minus_, &h_t_, &temp_matrix_);
    arm_mat_mult_f32(&temp_matrix_, &temp_matrix1_, &k_);
}

void kalmanfilter::update_x_hat()
{
    temp_vector_.numRows = h_.numRows;
    temp_vector_.numCols = 1;
    arm_mat_mult_f32(&h_, &x_hat_minus_, &temp_vector_);
    temp_vector1_.numRows = measurement_.numRows;
    temp_vector1_.numCols = 1;
    arm_mat_sub_f32(&measurement_, &temp_vector_, &temp_vector1_);
    temp_vector_.numRows = k_.numRows;
    temp_vector_.numCols = 1;
    arm_mat_mult_f32(&k_, &temp_vector1_, &temp_vector_);
    arm_mat_add_f32(&x_hat_minus_, &temp_vector_, &x_hat_);
}

void kalmanfilter::update_p()
{
    temp_matrix_.numRows = k_.numRows;
    temp_matrix_.numCols = h_.numCols;
    temp_matrix1_.numRows = temp_matrix_.numRows;
    temp_matrix1_.numCols = p_minus_.numCols;
    arm_mat_mult_f32(&k_, &h_, &temp_matrix_);
    arm_mat_mult_f32(&temp_matrix_, &p_minus_, &temp_matrix1_);
    arm_mat_sub_f32(&p_minus_, &temp_matrix1_, &p_);
}

void kalmanfilter::adjust_hkr()
{
    measurement_valid_num_ = 0;

    std::memcpy(measurement_data_, measured_vector_, sizeof(float) * measurement_size_);
    std::memset(measured_vector_, 0, sizeof(float) * measurement_size_);

    std::memset(r_data_, 0, sizeof(float) * measurement_size_ * measurement_size_);
    std::memset(h_data_, 0, sizeof(float) * measurement_size_ * state_size_);
    for (uint8_t i = 0; i < measurement_size_; ++i)
    {
        if (measurement_data_[i] != 0.0f)
        {
            measurement_data_[measurement_valid_num_] = measurement_data_[i];
            temp_[measurement_valid_num_] = i;
            h_data_[state_size_ * measurement_valid_num_ + measurement_map_[i] - 1] =
                measurement_degree_[i];
            measurement_valid_num_++;
        }
    }
    for (uint8_t i = 0; i < measurement_valid_num_; ++i)
    {
        r_data_[i * measurement_valid_num_ + i] = mat_r_diagonal_elements_[temp_[i]];
    }

    h_.numRows = measurement_valid_num_;
    h_.numCols = state_size_;
    h_t_.numRows = state_size_;
    h_t_.numCols = measurement_valid_num_;
    r_.numRows = measurement_valid_num_;
    r_.numCols = measurement_valid_num_;
    k_.numRows = state_size_;
    k_.numCols = measurement_valid_num_;
    measurement_.numRows = measurement_valid_num_;
}

float* kalmanfilter::update()
{
    measure();
    update_x_hat_minus();
    update_p_minus();

    if (measurement_valid_num_ != 0U || !use_auto_adjustment_)
    {
        update_k();
        update_x_hat();
        update_p();
    }
    else
    {
        std::memcpy(x_hat_data_, x_hat_minus_data_, sizeof(float) * state_size_);
        std::memcpy(p_data_, p_minus_data_, sizeof(float) * state_size_ * state_size_);
    }

    for (uint8_t i = 0; i < state_size_; ++i)
    {
        if (p_data_[i * state_size_ + i] < state_min_variance_[i])
        {
            p_data_[i * state_size_ + i] = state_min_variance_[i];
        }
    }
    std::memcpy(filtered_value_, x_hat_data_, sizeof(float) * state_size_);
    return filtered_value_;
}

kalmanfilter1D::kalmanfilter1D() = default;

void kalmanfilter1D::clear()
{
    last_p_ = 0.02f;
    now_p_ = 0.0f;
    result_ = 0.0f;
    kg_ = 0.0f;
    q_ = 0.001f;
    r_ = 0.543f;
}

void kalmanfilter1D::set_kg(float kg)
{
    kg_ = kg;
}
void kalmanfilter1D::set_q(float q)
{
    q_ = q;
}
void kalmanfilter1D::set_r(float r)
{
    r_ = r;
}

float kalmanfilter1D::update(float input)
{
    now_p_ = last_p_ + q_;
    kg_ = now_p_ * (1.0f / (now_p_ + r_));
    result_ = result_ + kg_ * (input - result_);
    last_p_ = (1.0f - kg_) * now_p_;
    return result_;
}

} // namespace filter

