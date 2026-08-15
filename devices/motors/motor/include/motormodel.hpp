#pragma once

#include "djimotors.hpp"
#include "dmmotors.hpp"
#include "robot_config.hpp"

namespace motors
{

template <robot::motors::model Model>
struct dji_motor_type;

template <>
struct dji_motor_type<robot::motors::model::dji_m2006>
{
    using type = m2006;
};

template <>
struct dji_motor_type<robot::motors::model::dji_m3508>
{
    using type = m3508;
};

template <>
struct dji_motor_type<robot::motors::model::dji_gm6020>
{
    using type = gm6020;
};

template <>
struct dji_motor_type<robot::motors::model::dji_xroll>
{
    using type = xroll;
};

template <robot::motors::model Model>
using dji_motor_t = typename dji_motor_type<Model>::type;

template <robot::motors::model Model>
struct dm_motor_type;

template <>
struct dm_motor_type<robot::motors::model::dm_dm4310>
{
    using type = dm4310;
};

template <>
struct dm_motor_type<robot::motors::model::dm_dm8009p>
{
    using type = dm8009p;
};

template <robot::motors::model Model>
using dm_motor_t = typename dm_motor_type<Model>::type;

} // namespace motors
