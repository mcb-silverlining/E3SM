#include <catch2/catch.hpp>
#include <chrono>
#include <iomanip>
#include <iostream>
#include <fstream>

#include "share/util/scream_array_utils.hpp"
#include "share/util/scream_universal_constants.hpp"
#include "share/util/scream_utils.hpp"
#include "share/util/scream_time_stamp.hpp"
#include "share/util/scream_setup_random_test.hpp"
#include "share/util/scream_vertical_interpolation.hpp"
#include "ekat/ekat_parse_yaml_file.hpp"


TEST_CASE("vertical_interpolation"){
  using namespace scream;

  ekat::Comm io_comm(MPI_COMM_WORLD);
  using vos_type = std::vector<std::string>;
  ekat::ParameterList params_f;
  ekat::parse_yaml_file("io_vertical_interpolation_test.yaml",params_f);
  std::string filename = params_f.get<std::string>("Filename");
  //std::cout<<"Finn test name for filename: "<<filename<<std::endl;
  vos_type sv = params_f.get<vos_type>("Field Names");
  //std::cout<<"First Field name: "<<sv[0]<<std::endl;
  //std::cout<<"Second Field name: "<<sv[1]<<std::endl;

  
  auto npacks_tgt_f = ekat::PackInfo<Spack::n>::num_packs(194);
  auto npacks_src_f = ekat::PackInfo<Spack::n>::num_packs(128);
  auto p_tgt_f = view_1d<Spack>("",npacks_tgt_f);
  auto p_tgt_f_c = Kokkos::create_mirror_view(ekat::scalarize(p_tgt_f));
  auto tmp_src_f = view_2d<Spack>("",866,npacks_src_f);
  auto tmp_src_f_c = Kokkos::create_mirror_view(ekat::scalarize(tmp_src_f));
  auto p_src_f = view_2d<Spack>("",866,npacks_src_f);
  auto p_src_f_c = Kokkos::create_mirror_view(ekat::scalarize(p_src_f));
  auto out_f = view_2d<Spack>("",866,npacks_tgt_f);
  auto out_f_c = Kokkos::create_mirror_view(ekat::scalarize(out_f));
  auto mask = view_2d<Smask>("",866,npacks_tgt_f);
  //auto mask = view_2d<Spack>("",866,npacks_tgt_f);
  //auto mask = view_2d<Sbool>("",866,npacks_tgt_f);
  //auto mask = view_2d<Smask>("",866);
  //auto mask_c = Kokkos::create_mirror_view(ekat::scalarize(mask));

  std::string line;
  //std::ifstream press_levels (filename);
  std::ifstream press_levels ("press_tgt_levels.txt");
  std::cout << "Get after press_levels.txt" << std::endl;
  int i=0;
  //std::cout<<"View size: "<<p_tgt_f.size()<<std::endl;
  //Kokkos::deep_copy(p_tgt_f_c, ekat::scalarize(p_tgt_f_c));
  if (press_levels.is_open()){
    while ( getline(press_levels,line) ){
      if (i < 194){
	//std::cout<<line<<std::endl;
	p_tgt_f_c(i) = log(std::stod(line));
	//mirror.data[i] = std::stod(line);
      }
      i++;
    }
  }
  press_levels.close();

  //if(sv[0] != "temp" && sv[1] != "temp"){
  //  return;
  //}
  
  std::string line_t;
  std::ifstream temp_levels ("temp_src_ne4_866col_128lay.txt");
  int i_t=0;
  int j_t=0;
  if (temp_levels.is_open()){
    while ( getline(temp_levels,line_t) ){
      tmp_src_f_c(i_t,j_t) = log(std::stod(line_t));
      j_t++;
      if (j_t == 128){
	i_t++;
	j_t=0;
      }
    }
  }
  temp_levels.close();
  
  std::string line_p;
  std::ifstream p_levels ("press_src_ne4_866col_128lay.txt");
  //col
  int i_p=0;
  //lev
  int j_p=0;
  if (p_levels.is_open()){
    while ( getline(p_levels,line_p) ){
      //std::cout<<line<<std::endl;
      p_src_f_c(i_p,j_p) = log(std::stod(line_p));
      j_p++;
      if (j_p == 128){
	i_p++;
	j_p=0;
      }
    }
  }
  p_levels.close();

  const int n_layers_src = 128;
  const int n_layers_tgt = 194;
  
  scream::perform_vertical_interpolation(p_src_f,
					 p_tgt_f,
					 tmp_src_f,
					 out_f,
					 mask,
					 n_layers_src,
					 n_layers_tgt);
  
  /*
  scream::perform_vertical_interpolation(p_src_f,
					 p_tgt_f,
					 tmp_src_f,
					 out_f,
					 n_layers_src,
					 n_layers_tgt);
  */
  
  //Make output file
  auto time_now = std::chrono::system_clock::now();
  const std::time_t t_c = std::chrono::system_clock::to_time_t(time_now);
  std::stringstream transTime;
  transTime << std::put_time(std::localtime(&t_c), "%Y-%m-%d-%H-%M-%S");
  std::string time = transTime.str();
  //std::cout << std::put_time(std::localtime(&t_c), "%Y-%m-%d-%H-%M-%S.\n") << std::endl;
  std::string fname = "output_" + time + ".txt";
  std::string fname_mask = "output_mask_" + time + ".txt";
  std::ofstream temp_new_file;
  //myfile.open ("output_utils.txt");
  temp_new_file.open (fname);
  std::ofstream mask_file;
  //myfile.open ("output_utils.txt");
  mask_file.open (fname_mask);
  
  std::string line_t_o;
  std::ifstream original_temp("output_log_original.txt"); 

  for(int col=0; col<866; col++){
    int ct = 0;
    for(int lev=0; lev<13; lev++){
      for (int p = 0; p<16;p++){
        ct=ct+1;
	if(ct == 195){break;}
	mask_file << mask(col,lev)[p];
	//mask_file << mask_tmp_1d(lev);
	mask_file << "\n";
      }
    }
  }
    
  for(int col=0; col<866; col++){
    //const auto mask_tmp = ekat::subview(mask,col);
    //const auto mask_tmp_1d = ekat::scalarize(mask_tmp);

    for(int lev=0; lev<194; lev++){
      getline(original_temp,line_t_o);
      std::stringstream out_f_c_str;
      out_f_c_str << exp(out_f_c(col,lev));
      //REQUIRE(out_f_c_str.str() == line_t_o);
      /*
      if(out_f_c_str.str() != line_t_o)
	{
	  std::cout<<"Test fails, not exactly the same"<<std::endl;
	  std::cout<<"out_f_c(col,lev): "<<out_f_c(col,lev)<<std::endl;
	  std::cout<<"std::stod(line_t_o): "<<std::stod(line_t_o)<<std::endl;
	}
      */
      temp_new_file << exp(out_f_c(col,lev));
      temp_new_file << "\n";
      //mask_file << mask(col,lev);
      //mask_file << mask_tmp_1d(lev);
      //mask_file << "\n";
    }
  }
  temp_new_file.close();
  original_temp.close();
  //Compare output file to previous output file to make sure the same

  std::string line_mask;
  std::ifstream output_mask("output_mask.txt"); 
}

TEST_CASE("contiguous_superset") {
  using namespace scream;

  std::string A = "A";
  std::string B = "B";
  std::string C = "C";
  std::string D = "D";
  std::string E = "E";
  std::string F = "F";
  std::string G = "G";

  using LOLS_type = std::list<std::list<std::string>>;

  // These three lists do not allow a superset from which they can all be
  // contiguously subviewed.
  LOLS_type lol1 = { {A,B}, {B,C}, {A,C} };
  REQUIRE(contiguous_superset(lol1).size()==0);

  // Input inner lists are not sorted
  REQUIRE_THROWS(contiguous_superset(LOLS_type{ {B,A} }));

  // The following should both allow the superset (A,B,C,D,E,F,G)
  // Note: lol3 is simply a shuffled version of lol2
  LOLS_type lol2 = { {A,B,C}, {B,C,D,E}, {C,D}, {C,D,E,F}, {D,E,F,G} };
  LOLS_type lol3 = { {D,E,F,G}, {C,D,E,F}, {A,B,C}, {C,D}, {B,C,D,E} };

  // Flipping a list is still a valid solution, so consider both tgt and its reverse.
  std::list<std::string> tgt = {A,B,C,D,E,F,G};
  std::list<std::string> tgt_rev = tgt;
  tgt_rev.reverse();

  auto superset2 = contiguous_superset(lol2);
  auto superset3 = contiguous_superset(lol3);
  REQUIRE ( (superset2==tgt || superset2==tgt_rev) );
  REQUIRE ( (superset3==tgt || superset3==tgt_rev) );
}

TEST_CASE ("time_stamp") {
  using namespace scream;
  using TS = util::TimeStamp;

  constexpr auto spd = constants::seconds_per_day;

  TS ts1 (2021,10,12,17,8,30);

  SECTION ("ctor_check") {
    REQUIRE (ts1.get_year()==2021);
    REQUIRE (ts1.get_month()==10);
    REQUIRE (ts1.get_day()==12);
    REQUIRE (ts1.get_hours()==17);
    REQUIRE (ts1.get_minutes()==8);
    REQUIRE (ts1.get_seconds()==30);
  }

  SECTION ("getters_checks") {
    // Julian day = frac_of_year_in_days.fraction_of_day, with frac_of_year_in_days=0 at Jan 1st.
    REQUIRE (ts1.frac_of_year_in_days()==(284 + (17*3600+8*60+30)/86400.0));
    REQUIRE (ts1.get_num_steps()==0);

    REQUIRE (ts1.get_date_string()=="2021-10-12");
    REQUIRE (ts1.get_time_string()=="17:08:30");
    REQUIRE (ts1.to_string()=="2021-10-12-61710");
  }

  SECTION ("comparisons") {
    REQUIRE (ts1==ts1);

    // Comparisons
    REQUIRE ( TS({2021,12,31},{23,59,59}) < TS({2022,1,1},{0,0,0}));
    REQUIRE ( TS({2022,1,1},{0,0,0}) <= TS({2022,1,1},{0,0,0}));
    REQUIRE ( (TS({2021,12,31},{23,59,59})+1) == TS({2022,1,1},{0,0,0}));
  }

  SECTION ("updates") {
    // Cannot rewind time
    REQUIRE_THROWS (ts1+=-10);

    auto ts2 = ts1 + 1;

    REQUIRE (ts1<ts2);
    REQUIRE (ts2<=ts2);

    // Update: check carries
    REQUIRE (ts2.get_seconds()==(ts1.get_seconds()+1));
    REQUIRE (ts2.get_minutes()==ts1.get_minutes());
    REQUIRE (ts2.get_hours()==ts1.get_hours());
    REQUIRE (ts2.get_day()==ts1.get_day());
    REQUIRE (ts2.get_month()==ts1.get_month());
    REQUIRE (ts2.get_year()==ts1.get_year());

    ts2 += 60;
    REQUIRE (ts2.get_seconds()==(ts1.get_seconds()+1));
    REQUIRE (ts2.get_minutes()==(ts1.get_minutes()+1));
    REQUIRE (ts2.get_hours()==ts1.get_hours());
    REQUIRE (ts2.get_day()==ts1.get_day());
    REQUIRE (ts2.get_month()==ts1.get_month());
    REQUIRE (ts2.get_year()==ts1.get_year());

    ts2 += 3600;
    REQUIRE (ts2.get_seconds()==(ts1.get_seconds()+1));
    REQUIRE (ts2.get_minutes()==(ts1.get_minutes()+1));
    REQUIRE (ts2.get_hours()==ts1.get_hours()+1);
    REQUIRE (ts2.get_day()==ts1.get_day());
    REQUIRE (ts2.get_month()==ts1.get_month());
    REQUIRE (ts2.get_year()==ts1.get_year());

    ts2 += spd;
    REQUIRE (ts2.get_seconds()==(ts1.get_seconds()+1));
    REQUIRE (ts2.get_minutes()==(ts1.get_minutes()+1));
    REQUIRE (ts2.get_hours()==(ts1.get_hours()+1));
    REQUIRE (ts2.get_day()==(ts1.get_day()+1));
    REQUIRE (ts2.get_month()==ts1.get_month());
    REQUIRE (ts2.get_year()==ts1.get_year());

    ts2 += spd*20;
    REQUIRE (ts2.get_seconds()==(ts1.get_seconds()+1));
    REQUIRE (ts2.get_minutes()==(ts1.get_minutes()+1));
    REQUIRE (ts2.get_hours()==(ts1.get_hours()+1));
    REQUIRE (ts2.get_day()==(ts1.get_day()+1+20-31)); // Add 20 days, subtract Oct 31 days (carry)
    REQUIRE (ts2.get_month()==(ts1.get_month()+1));
    REQUIRE (ts2.get_year()==ts1.get_year());

    ts2 += spd*365;
    REQUIRE (ts2.get_seconds()==ts1.get_seconds()+1);
    REQUIRE (ts2.get_minutes()==(ts1.get_minutes()+1));
    REQUIRE (ts2.get_hours()==(ts1.get_hours()+1));
    REQUIRE (ts2.get_day()==(ts1.get_day()+1+20-31)); // Add 20 days, subtract Oct 31 days (carry)
    REQUIRE (ts2.get_month()==(ts1.get_month()+1));
    REQUIRE (ts2.get_year()==(ts1.get_year()+1));

    REQUIRE (ts2.get_num_steps()==6);
  }

  SECTION ("leap_years") {
    // Check leap year correctness
    TS ts2({2000,2,28},{23,59,59});
    TS ts3({2012,2,28},{23,59,59});
    TS ts4({2100,2,28},{23,59,59});

    ts2 += 1;
    ts3 += 1;
    ts4 += 1;
#ifdef SCREAM_HAS_LEAP_YEAR
    REQUIRE (ts2.get_month()==2);
    REQUIRE (ts3.get_month()==2);
#else
    REQUIRE (ts2.get_month()==3);
    REQUIRE (ts3.get_month()==3);
#endif
    // Centennial years with first 2 digits not divisible by 4 are not leap
    REQUIRE (ts4.get_month()==3);
  }

  SECTION ("difference") {
    // Difference
    auto ts2 = ts1 + 3600;
    REQUIRE ( (ts2-ts1)==3600 );
    auto ts3 = ts1 + spd;
    REQUIRE ( (ts3-ts1)==spd );
    auto ts4 = ts1 + spd*10;
    REQUIRE ( (ts4-ts1)==spd*10 );
    auto ts5 = ts1 + spd*100;
    REQUIRE ( (ts5-ts1)==spd*100 );
    auto ts6 = ts1 + spd*1000;
    REQUIRE ( (ts6-ts1)==spd*1000 );
  }
}

TEST_CASE ("array_utils") {
  using namespace scream;

  auto engine = setup_random_test ();
  using IPDF = std::uniform_int_distribution<int>;
  IPDF pdf(1,10);

  auto total_size = [](const std::vector<int>& v) -> int {
    int s = 1;
    for (int i : v) {
      s *= i;
    }
    return s;
  };

  // Adds one to fastest striding, doing carrying (if possible) based on max dims d
  // Note: cannot use recursion with a pure lambda
  std::function<bool(int*,int,int*)> add_one = [&](int* v, int n, int* d) -> bool{
    // Increase fastest striding index
    ++v[n];

    // If we reached d[n], we need to carry
    if (v[n]>=d[n]) {
      if (n>0) {
        // Try to carry
        v[n] = 0;

        bool b = add_one(v,n-1,d);

        if (not b) {
          // There was no room to carry. Reset v[n]=d[n] and return false
          v[n] = d[n];
          return false;
        }
      } else {
        v[0] = d[0];
        return false;
      }
    }

    return true;
  };

  for (int rank : {1,2,3,4,5,6}) {
    std::vector<int> dims(rank);
    for (int d=0; d<rank; ++d) {
      dims[d] = pdf(engine);
    }

    std::vector<int> ind(rank,0);
    auto s = total_size(dims);
    for (int idx_1d=0; idx_1d<s; ++idx_1d) {
      auto idx_nd = unflatten_idx(dims,idx_1d);    

      std::cout << "idx1d: " << idx_1d << "\n";
      std::cout << "  indices:";
      for (auto i : ind) {
        std::cout << " " << i;
      }
      std::cout << "\n  unflatten:";
      for (auto i : idx_nd) {
        std::cout << " " << i;
      }
      std::cout << "\n";
      REQUIRE (idx_nd==ind);
      add_one(ind.data(),rank-1,dims.data());
    }
  }
}
