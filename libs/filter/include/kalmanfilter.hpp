#pragma once

#include <cmath>
#include <cstdint>

#include "arm_math.h"

namespace filter 
{

class kalmanfilter 
{
 public:
  kalmanfilter(uint8_t state_size, uint8_t control_size, uint8_t measurement_size);
  virtual ~kalmanfilter() = default;

  float* update();

  float* filtered_value_ = nullptr;
  float* measured_vector_ = nullptr;
  float* control_vector_ = nullptr;

  uint8_t state_size_ = 0;
  uint8_t control_size_ = 0;
  uint8_t measurement_size_ = 0;

  bool use_auto_adjustment_ = false;
  uint8_t measurement_valid_num_ = 0;

  uint8_t* measurement_map_ = nullptr;
  float* measurement_degree_ = nullptr;
  float* mat_r_diagonal_elements_ = nullptr;
  float* state_min_variance_ = nullptr;

  arm_matrix_instance_f32 x_hat_{};
  arm_matrix_instance_f32 x_hat_minus_{};
  arm_matrix_instance_f32 control_{};
  arm_matrix_instance_f32 measurement_{};
  arm_matrix_instance_f32 p_{};
  arm_matrix_instance_f32 p_minus_{};
  arm_matrix_instance_f32 f_{};
  arm_matrix_instance_f32 f_t_{};
  arm_matrix_instance_f32 b_{};
  arm_matrix_instance_f32 h_{};
  arm_matrix_instance_f32 h_t_{};
  arm_matrix_instance_f32 q_{};
  arm_matrix_instance_f32 r_{};
  arm_matrix_instance_f32 k_{};

 protected:
  virtual void measure();
  virtual void update_x_hat_minus();
  virtual void update_p_minus();
  virtual void update_k();
  virtual void update_x_hat();
  virtual void update_p();
  virtual void adjust_hkr();

  void* allocate(size_t size);

  uint8_t* temp_ = nullptr;
  float* x_hat_data_ = nullptr;
  float* x_hat_minus_data_ = nullptr;
  float* control_data_ = nullptr;
  float* measurement_data_ = nullptr;
  float* p_data_ = nullptr;
  float* p_minus_data_ = nullptr;
  float* f_data_ = nullptr;
  float* f_t_data_ = nullptr;
  float* b_data_ = nullptr;
  float* h_data_ = nullptr;
  float* h_t_data_ = nullptr;
  float* q_data_ = nullptr;
  float* r_data_ = nullptr;
  float* k_data_ = nullptr;

  arm_matrix_instance_f32 s_{};
  arm_matrix_instance_f32 temp_matrix_{};
  arm_matrix_instance_f32 temp_matrix1_{};
  arm_matrix_instance_f32 temp_vector_{};
  arm_matrix_instance_f32 temp_vector1_{};
  float* s_data_ = nullptr;
  float* temp_matrix_data_ = nullptr;
  float* temp_matrix_data1_ = nullptr;
  float* temp_vector_data_ = nullptr;
  float* temp_vector_data1_ = nullptr;
};

class kalmanfilter1D 
{
 public:
  kalmanfilter1D();

  void clear();
  void set_kg(float kg);
  void set_q(float q);
  void set_r(float r);
  float update(float input);

 private:
  float last_p_ = 0.02f;
  float now_p_ = 0.0f;
  float result_ = 0.0f;
  float kg_ = 0.0f;
  float q_ = 0.001f;
  float r_ = 0.543f;
};

}  // namespace filter
