#include "catch2/catch.hpp"

#include "share/util/scream_common_physics_functions.hpp"
#include "share/util/scream_common_physics_impl.hpp"
#include "physics/share/tests/physics_unit_tests_common.hpp"

#include "ekat/ekat_pack.hpp"
#include "ekat/kokkos/ekat_kokkos_utils.hpp"
#include "ekat/util/ekat_test_utils.hpp"

namespace scream {
namespace physics {
namespace unit_test {

template <typename D>
struct UnitWrap::UnitTest<D>::TestUniversal
{

//-----------------------------------------------------------------------------------------------//
  static void run()
  {
    using physicscommon      = scream::PhysicsFunctions<Device>;
    using physicscommon = scream::PhysicsFunctions<HostDevice>;

    using Spack = ekat::Pack<Scalar,SCREAM_SMALL_PACK_SIZE>;

    int num_levs = 100; // Number of levels to use for tests.

    static constexpr Scalar p0     = C::P0;
    static constexpr Scalar Rd     = C::RD;
    static constexpr Scalar inv_cp = C::INV_CP;
    static constexpr Scalar tmelt  = C::Tmelt;
    static constexpr Scalar ggr    = C::gravit;
    static constexpr Scalar test_tol = C::macheps*1e3;

    using view_1d = ekat::KokkosTypes<DefaultDevice>::view_1d<Scalar>;
    using sview_1d = ekat::KokkosTypes<DefaultDevice>::view_1d<Spack>;
    const Int num_pack = ekat::npack<Spack>(num_levs);
    const Int num_pack_int = ekat::npack<Spack>(num_levs+1);
    // Compute random values for tests
    sview_1d temperature_packed("temperature",num_pack),
             height_packed("height",num_pack),
             qv_packed("qv",num_pack),
             pressure_packed("pressure",num_pack),
             pseudo_density_packed("pseudo_density",num_pack),
             dz_for_testing_packed("dz_for_testing",num_pack);
    view_1d surface_height("surface_height",1);
    // Allocate memory for test outputs
    view_1d exner("exner",num_levs),
            theta("theta",num_levs),
            T_mid_from_pot("T_mid_from_pot",num_levs),
            T_virtual("T_virtual",num_levs),
            T_mid_from_virt("T_mid_from_virt",num_levs),
            dse("dse",num_levs),
            dz("dz",num_levs),
            z_int("z_int",num_levs+1);
    sview_1d exner_packed("exner",num_pack),
             theta_packed("theta",num_pack),
             T_mid_from_pot_packed("T_mid_from_pot",num_pack),
             T_virtual_packed("T_virtual",num_pack),
             T_mid_from_virt_packed("T_mid_from_virt",num_pack),
             dse_packed("dse",num_pack),
             dz_packed("dz",num_pack),
             z_int_packed("z_int",num_pack_int);

    // Construct random input data
    std::random_device rdev;
    using rngAlg = std::mt19937_64;
    const unsigned int catchRngSeed = Catch::rngSeed();
    const unsigned int seed = catchRngSeed==0 ? rdev() : catchRngSeed;
    // Print seed to screen to trace tests that fail.
    std::cout << "seed: " << seed << (catchRngSeed==0 ? " (catch rng seed was 0)\n" : "\n");
    rngAlg engine(seed);
    using RPDF = std::uniform_real_distribution<Scalar>;
    RPDF pdf_qv(1e-3,1e3),
         pdf_dp(1.0,100.0),
         pdf_pres(0.0,p0),
         pdf_temp(200.0,400.0),
         pdf_height(0.0,1e5),
         pdf_surface(100.0,400.0);

    ekat::genRandArray(temperature_packed,engine,pdf_temp);
    ekat::genRandArray(height_packed,engine,pdf_height);
    ekat::genRandArray(surface_height,engine,pdf_surface);
    ekat::genRandArray(qv_packed,engine,pdf_qv);
    ekat::genRandArray(pressure_packed,engine,pdf_pres);
    ekat::genRandArray(pseudo_density_packed,engine,pdf_dp);

    // Construct a simple set of `dz` values for testing the z_int function
    auto dz_for_testing_host = Kokkos::create_mirror_view(ekat::scalarize(dz_for_testing_packed));
    for (int k = 0;k<num_levs;k++)
    {
      dz_for_testing_host[k] = num_levs-k;
    }
    Kokkos::deep_copy(dz_for_testing_packed,dz_for_testing_host);

    view_1d temperature(reinterpret_cast<Scalar*>(temperature_packed.data()),num_levs),
            height(reinterpret_cast<Scalar*>(height_packed.data()),num_levs),
            qv(reinterpret_cast<Scalar*>(qv_packed.data()),num_levs),
            pressure(reinterpret_cast<Scalar*>(pressure_packed.data()),num_levs),
            pseudo_density(reinterpret_cast<Scalar*>(pseudo_density_packed.data()),num_levs),
            dz_for_testing(reinterpret_cast<Scalar*>(dz_for_testing_packed.data()),num_levs);

    // Run tests using Scalars
    Scalar t_result, T0, z0, ztest, ptest, dp0, qv0;
    // Exner property tests:
    // exner_function(p0) should return 1.0
    // exner_function(0.0) should return 0.0
    // exner_function(2*p0) should return 2**(Rd/cp)
    ptest = p0;
    REQUIRE(physicscommon::exner_function(ptest)==1.0);
    ptest = 0.0;
    REQUIRE(physicscommon::exner_function(ptest)==0.0);
    ptest = 4.0; t_result = pow(2.0,Rd*inv_cp);
    REQUIRE(std::abs(physicscommon::exner_function(ptest)/physicscommon::exner_function(ptest/2)-t_result)<test_tol);
    // Potential temperature property tests
    // theta=T when p=p0
    // theta(T=0) = 0
    // T(theta=0) = 0
    // T(theta(T0)) = T0
    // theta(T(theta0)) = theta0
    T0 = 100.0;
    REQUIRE(physicscommon::calculate_theta_from_T(T0,p0)==T0);
    REQUIRE(physicscommon::calculate_theta_from_T(0.0,1.0)==0.0);
    REQUIRE(physicscommon::calculate_T_from_theta(0.0,1.0)==0.0);
    REQUIRE(physicscommon::calculate_T_from_theta(physicscommon::calculate_theta_from_T(100.0,1.0),1.0)==100.0); 
    REQUIRE(physicscommon::calculate_theta_from_T(physicscommon::calculate_T_from_theta(100.0,1.0),1.0)==100.0);
    // Virtual temperature property tests
    // T_virt(T=0) = 0.0
    // T_virt(T=T0,qv=0) = T0
    // T(T_virt=0) = 0.0
    // T(T_virt=T0,qv=0) = T0
    // T_virt(T=T0) = T0
    // T(T_virt=T0) = T0
    REQUIRE(physicscommon::calculate_virtual_temperature(0.0,1e-6)==0.0);
    REQUIRE(physicscommon::calculate_virtual_temperature(100.0,0.0)==100.0);
    REQUIRE(physicscommon::calculate_temperature_from_virtual_temperature(0.0,1e-6)==0.0);
    REQUIRE(physicscommon::calculate_temperature_from_virtual_temperature(100.0,0.0)==100.0);
    REQUIRE(physicscommon::calculate_virtual_temperature(physicscommon::calculate_temperature_from_virtual_temperature(100.0,1.0),1.0)==100.0); 
    REQUIRE(physicscommon::calculate_temperature_from_virtual_temperature(physicscommon::calculate_virtual_temperature(100.0,1.0),1.0)==100.0);
    // DSE property tests
    // calculate_dse(T=0.0, z=0.0) = surf_geopotential
    // calculate_dse(T=1/cp, z=1/gravity) = surf_potential+2
    T0=0.0; ztest=0.0; z0=10.0;
    REQUIRE(physicscommon::calculate_dse(T0,ztest,z0)==10.0);
    T0=inv_cp; ztest=1.0/ggr; z0=0.0;
    REQUIRE(physicscommon::calculate_dse(T0,ztest,z0)==z0+2.0);
    // DZ tests
    // calculate_dz(pseudo_density=0) = 0
    // calculate_dz(T=0) = 0
    // calculate_dz(pseudo_density=p0,p_mid=p0,T=1.0,qv=0) = Rd/ggr
    // calculate_dz(pseudo_density=ggr,p_mid=Rd,T=T0,qv=0) = T0
    dp0=0.0; ptest=p0; T0=100.0; qv0=1e-5;
    REQUIRE(physicscommon::calculate_dz(dp0,ptest,T0,qv0)==0.0);
    dp0=100.0; ptest=p0; T0=0.0; qv0=1e-5;
    REQUIRE(physicscommon::calculate_dz(dp0,ptest,T0,qv0)==0.0);
    dp0=p0; ptest=p0; T0=1.0; qv0=0.0;
    REQUIRE(physicscommon::calculate_dz(dp0,ptest,T0,qv0)==Rd/ggr);
    dp0=ggr; ptest=Rd; T0=100.0; qv0=0.0;
    REQUIRE(physicscommon::calculate_dz(dp0,ptest,T0,qv0)==T0);
    
    // Run tests on full views
    TeamPolicy policy(ekat::ExeSpaceUtils<ExeSpace>::get_default_team_policy(1, 1));
    Kokkos::parallel_for("test_universal_physics", policy, KOKKOS_LAMBDA(const MemberType& team) {
      // Constants used in testing (necessary to ensure SP build works)
      // Exner property tests:
      // exner_function(pressure) should work for Scalar and for Spack.
      physicscommon::exner_function(team,pressure,exner);
      physicscommon::exner_function(team,pressure_packed,exner_packed);
      // Potential temperature property tests
      // calculate_theta_from_T(T,pressure) should work
      // calculate_T_from_theta(theta,pressure) should work for Scalar and for Spack
      physicscommon::calculate_theta_from_T(team,temperature,pressure,theta);
      physicscommon::calculate_T_from_theta(team,theta,pressure,T_mid_from_pot);
      physicscommon::calculate_theta_from_T(team,temperature_packed,pressure_packed,theta_packed);
      physicscommon::calculate_T_from_theta(team,theta_packed,pressure_packed,T_mid_from_pot_packed);
      // Virtual temperature property tests
      // calculate_virtual_temperature(temperature,qv) should work for Scalar and for Spack
      // calculate_temperature_from_virtual_temperature should work for Scalar and for Spack
      physicscommon::calculate_virtual_temperature(team,temperature,qv,T_virtual);
      physicscommon::calculate_temperature_from_virtual_temperature(team,T_virtual,qv,T_mid_from_virt);
      physicscommon::calculate_virtual_temperature(team,temperature_packed,qv_packed,T_virtual_packed);
      physicscommon::calculate_temperature_from_virtual_temperature(team,T_virtual_packed,qv_packed,T_mid_from_virt_packed);
      // DSE property tests
      // calculate_dse should work for Scalar and for Spack
      physicscommon::calculate_dse(team,temperature,height,surface_height(0),dse);
      physicscommon::calculate_dse(team,temperature_packed,height_packed,surface_height(0),dse_packed);
      // DZ tests
      // calculate_dz should work for Scalar and for Spack
      physicscommon::calculate_dz(team,pseudo_density,pressure,temperature,qv,dz);
      physicscommon::calculate_dz(team,pseudo_density_packed,pressure_packed,temperature_packed,qv_packed,dz_packed);
      // z_int property tests
      // calculate_z_int should work for Scalar and for Spack
      physicscommon::calculate_z_int(team,num_levs,dz_for_testing,z_int);
      physicscommon::calculate_z_int(team,num_levs,dz_for_testing_packed,z_int_packed);

    }); // Kokkos parallel_for "test_universal_physics"

    Kokkos::fence();
    auto exner_host           = Kokkos::create_mirror_view(exner);
    auto theta_host           = Kokkos::create_mirror_view(theta);
    auto T_mid_from_pot_host  = Kokkos::create_mirror_view(T_mid_from_pot);
    auto T_virtual_host       = Kokkos::create_mirror_view(T_virtual);
    auto T_mid_from_virt_host = Kokkos::create_mirror_view(T_mid_from_virt);
    auto dse_host             = Kokkos::create_mirror_view(dse);
    auto z_int_host           = Kokkos::create_mirror_view(z_int);
    auto dz_host              = Kokkos::create_mirror_view(dz);
    auto temperature_host     = Kokkos::create_mirror_view(temperature);
    auto pressure_host        = Kokkos::create_mirror_view(pressure);
    auto qv_host              = Kokkos::create_mirror_view(qv);

    auto exner_pack_host           = Kokkos::create_mirror_view(exner_packed);
    auto theta_pack_host           = Kokkos::create_mirror_view(theta_packed);
    auto T_mid_from_pot_pack_host  = Kokkos::create_mirror_view(T_mid_from_pot_packed);
    auto T_virtual_pack_host       = Kokkos::create_mirror_view(T_virtual_packed);
    auto T_mid_from_virt_pack_host = Kokkos::create_mirror_view(T_mid_from_virt_packed);
    auto dse_pack_host             = Kokkos::create_mirror_view(dse_packed);
    auto z_int_pack_host           = Kokkos::create_mirror_view(z_int_packed);
    auto dz_pack_host              = Kokkos::create_mirror_view(dz_packed);

    Kokkos::deep_copy(exner_host           , exner);
    Kokkos::deep_copy(theta_host           , theta);
    Kokkos::deep_copy(T_mid_from_pot_host  , T_mid_from_pot);
    Kokkos::deep_copy(T_virtual_host       , T_virtual);
    Kokkos::deep_copy(T_mid_from_virt_host , T_mid_from_virt);
    Kokkos::deep_copy(dse_host             , dse);
    Kokkos::deep_copy(z_int_host           , z_int);
    Kokkos::deep_copy(dz_host              , dz);
    Kokkos::deep_copy(temperature_host     , temperature);
    Kokkos::deep_copy(pressure_host        , pressure);
    Kokkos::deep_copy(qv_host              , qv);

    Kokkos::deep_copy(exner_pack_host           , exner_packed);
    Kokkos::deep_copy(theta_pack_host           , theta_packed);
    Kokkos::deep_copy(T_mid_from_pot_pack_host  , T_mid_from_pot_packed);
    Kokkos::deep_copy(T_virtual_pack_host       , T_virtual_packed);
    Kokkos::deep_copy(T_mid_from_virt_pack_host , T_mid_from_virt_packed);
    Kokkos::deep_copy(dse_pack_host             , dse_packed);
    Kokkos::deep_copy(z_int_pack_host           , z_int_packed);
    Kokkos::deep_copy(dz_pack_host              , dz_packed);
    //Kokkos::parallel_for(Kokkos::TeamThreadRange(team,num_levs+1), [&] (const int k)
    for(int k=0;k<num_levs;k++)
    {
     int ipack = k / Spack::n;
     int ivec  = k % Spack::n;
      // Make sure all columnwise results don't contain any obvious errors:
      // exner
      REQUIRE(exner_host(k)==exner_pack_host(ipack)[ivec]);
      REQUIRE(!isnan(exner_host(k)));
      REQUIRE(!(exner_host(k)<0));
      // potential temperature
      REQUIRE(theta_host(k)==theta_pack_host(ipack)[ivec]);
      REQUIRE(!isnan(theta_host(k)));
      REQUIRE(!(theta_host(k)<0));
      REQUIRE(theta_host(k)==physicscommon::calculate_theta_from_T(temperature_host(k),pressure_host(k)));
      // temperature from potential temperature
      REQUIRE(T_mid_from_pot_host(k)==T_mid_from_pot_pack_host(ipack)[ivec]);
      REQUIRE(!isnan(T_mid_from_pot_host(k)));
      REQUIRE(!(T_mid_from_pot_host(k)<0));
      REQUIRE(T_mid_from_pot_host(k)==physicscommon::calculate_T_from_theta(theta_host(k),pressure_host(k)));
      // virtual temperature
      REQUIRE(std::abs(T_virtual_host(k)-T_virtual_pack_host(ipack)[ivec])<test_tol);
      REQUIRE(!isnan(T_virtual_host(k)));
      REQUIRE(!(T_virtual_host(k)<0));
      REQUIRE(T_virtual_host(k)==physicscommon::calculate_virtual_temperature(temperature_host(k),qv_host(k)));
      // temperature from virtual temperature
      REQUIRE(std::abs(T_mid_from_virt_host(k)-T_mid_from_virt_pack_host(ipack)[ivec])<test_tol);
      REQUIRE(!isnan(T_mid_from_virt_host(k)));
      REQUIRE(!(T_mid_from_virt_host(k)<0));
      // DSE
      REQUIRE(dse_host(k)==dse_pack_host(ipack)[ivec]);
      REQUIRE(!isnan(dse_host(k)));
      REQUIRE(!(dse_host(k)<0));
      // dz
      REQUIRE(std::abs(dz_host(k)-dz_pack_host(ipack)[ivec])<test_tol);
      REQUIRE(!isnan(dz_host(k)));
      REQUIRE(!(dz_host(k)<=0));
      // z_int
      REQUIRE(z_int_host(k)==z_int_pack_host(ipack)[ivec]);
      const auto k_bwd = num_levs-k;
      REQUIRE(z_int_host(k_bwd)==k*(k+1)/2);
      REQUIRE(!isnan(z_int_host(k)));
      REQUIRE(!(z_int_host(k)<0));
    }

  } // run
}; // end of TestUniversal struct

} // namespace unit_test
} // namespace physics
} // namespace scream

namespace{

TEST_CASE("common_physics_functions_test", "[common_physics_functions_test]"){
  scream::physics::unit_test::UnitWrap::UnitTest<scream::DefaultDevice>::TestUniversal::run();

 } // TEST_CASE

} // namespace
