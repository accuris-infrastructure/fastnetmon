#!/usr/bin/perl

###
### This tool builds all binary dependencies required for FastNetMon
###


use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/perllib";

use Fastnetmon;
use Getopt::Long;

#
# CentOS
# sudo yum install perl perl-Archive-Tar
#

my $library_install_folder = '/opt/fastnetmon-community/libraries';

my $os_type = '';  
my $distro_type = '';  
my $distro_version = '';  
my $distro_architecture = '';  
my $appliance_name = ''; 

my $temp_folder_for_building_project = `mktemp -d /tmp/fastnetmon.build.dir.XXXXXXXXXX`;
chomp $temp_folder_for_building_project;

unless ($temp_folder_for_building_project && -e $temp_folder_for_building_project) {
    die "Can't create temp folder in /tmp for building project: $temp_folder_for_building_project\n";
}

# Pass log path to module
$Fastnetmon::install_log_path = "/tmp/fastnetmon_install_$$.log";

# We do not need default very safe permissions
exec_command("chmod 755 $temp_folder_for_building_project");

my $start_time = time();

my $fastnetmon_code_dir = "$temp_folder_for_building_project/fastnetmon/src";

unless (-e $library_install_folder) {
    exec_command("mkdir -p $library_install_folder");
}

main();

### Functions start here
sub main {
    my $machine_information = Fastnetmon::detect_distribution();

    unless ($machine_information) {
        die "Could not collect machine information\n";
    }

    $distro_version = $machine_information->{distro_version};
    $distro_type = $machine_information->{distro_type};
    $os_type = $machine_information->{os_type};
    $distro_architecture = $machine_information->{distro_architecture};
    $appliance_name = $machine_information->{appliance_name};
	
    $Fastnetmon::library_install_folder = $library_install_folder;
    $Fastnetmon::temp_folder_for_building_project = $temp_folder_for_building_project;

    # Install build dependencies
    my $dependencies_install_start_time = time();
    install_build_dependencies();

    print "Installed dependencies in ", time() - $dependencies_install_start_time, " seconds\n";

    # Init environment
    init_compiler();

    # We do not use prefix "lib" in names as all of them are libs and it's meaning less
    # We use target folder names in this list for clarity
    # Versions may be in different formats and we do not use them yet
    my @required_packages = (
        'pcap_1_10_4',
        # 'gcc', # we build it separately as it requires excessive amount of time
        'openssl_1_1_1q',
        'cmake_3_23_4',
        
        'boost_build_4_9_2',
        'icu_65_1',
        'boost_1_81_0',

        'capnproto_0_8_0',
        'hiredis_0_14',
        'mongo_c_driver_1_23_0',
        
        # gRPC dependencies 
        're2_2022_12_01',
        'abseil_2022_06_23',        
        'zlib_1_2_13',,
        'cares_1_18_1',

        'protobuf_21_12',
        'grpc_1_49_2',
        
        'elfutils_0_186',
        'bpf_1_0_1',
       
        'rdkafka_1_7_0',
        'cppkafka_0_3_1',

        'gobgp_3_12_0',
        'log4cpp_1_1_4',
        'gtest_1_13_0'
    );

    # Accept package name from command line argument
    if (scalar @ARGV > 0) {
        @required_packages = @ARGV;
    }

    # To guarantee that binary dependencies are not altered in storage side we store their hashes in repository
    my $binary_build_hashes = { 
        'gcc_12_1_0' => {
            'debian:9'            => '',
            'debian:10'           => 'ae677794b9941f99d0f0946c2c35b804b6aec375176fddb08f4f3eb38f2bb1fc74467fae199780bf0e19d3295adf950e350ae8c18617aa54a36795529aa8e4f0',
            
            'debian:11'           => '54573971c7eb61e48ba8b6bdb5dd82e652d945e449aac896c1c67fe44ac679811da735f2024f11d22c72afe7020304b0b1604c193da03b035aa2d8828714338d',
            'debian:aarch64:11'   => '',
            
            'debian:12' => 'f4fb617a7b4346152ead7447ff1477e65befb9b80c5c313bf02e14727ffb51eaa3fabe14ead96d0dda9aa0730736968d656fedbc27d32ac172763ae530fb677c',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '9828b83e6eba5d93253134d69ac8b19f1824ead2a3dfb545df7e3de62ae47cc1ab1505372a8c6d67034be3ca0d4cd75972e5b856511d225d70b850717dee772e',
            'ubuntu:aarch64:20.04'=> '',
            
            'ubuntu:22.04'        => 'a5a337754769bb9b3198de7eae0de1cd18e44ae62b32ab6760fdd9dbd0e27c7dae39d7e777486852e032dd66d23656e11278cf4cca22795c46ba385f76e3a0e2',
            'ubuntu:aarch64:22.04'=> '',

            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',
        },
        'openssl_1_1_1q'        => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '2f45947009290acc09ca0c5c6cfe6a4ca19faee59ab85f0b3bf9316146a249e5d537e32110cb0c1c08babdf8a60d8fc83bffb77a29ba2f95f4126dbcaf06f5a3',
            
            'debian:11'           => '076bb0f44da722801b16a6934d6731f326b9005506a045c1512d9f0bf83984c4e080cb494c4a18a0bc38f7a099e231a67543e5a4e8d4e7ee61ae138a568fb4fa',
            'debian:aarch64:11'   => '',

            'debian:12' => 'fb33424049581e1fe0d288e8be98e53db0f13e9ec86d798f828d69ca11a6544552e778aefe6604847fddf67ff8d9ab9c1a86f2bc726d292375fff1e20947b4cf',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => 'ed7a5a38344b0dc30e8240208f5e81689cbf8ec0effb4f801dbc4a8cc4c4e723356f7d283a03bcfbbc9e0c18252374a1c7d718dc87c2b96654c43b43c3aebac3',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'fc25da614a93466894d479b962dd97390a623fd2e12084484490efe0be3e82b8c594640386f18440ef724d3086b95230ceda59ff214a7478dba32959d20380eb',
            'ubuntu:aarch64:22.04'=> '',
        }, 
        'cmake_3_23_4'          => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '23c83046937cca31c1b9632b70260da11f2f806407e3f5450c778686e7e1cf330cad86e5eaf9e03b600f79fe85fceeee4b7958b1dc74092e8fb16684cf24913f',
            
            'debian:11'           => '342fe357b9a780ee688005524fc6c4c1dc5ada3b79624c292b489af99dac402ec44a328e62503294821b96a04a75afcf6d3898c934a0ccbce1c4376e4c16abb3',
            'debian:aarch64:11'   => '',

            'debian:12' => '70c1d8c1b5891aefed8395b773799e9c92f90dda4beba8b05ea8ee14a90398ef2fdef024fdf389ba72406fe665891de20eb71b3ba41eeff74785ad50a6e549a8',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '738aa173802ade300f7ef9c2878a9faaeabbee6f5234640efec9afba23fa961dbaeeb00138b4ea940819ced1dabfcfe43af1b8deff0ddfbafba15bc2a9df2912',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'f89e6d96eef88ec54b537480fb4128f4838e065cdf60c607465f0fb4281fae30f2a27ec94d1074e34bf98f44ec7d6cff1eb1ea585ee025d7d8c007a2fa08dd45',
            'ubuntu:aarch64:22.04'=> '',
        },
        'boost_build_4_9_2'     => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => 'a4d52a1577ea4c4ef24504d65e459af2178d182775bcc7c5884a78a93cabd58c1fc089c9b6f629051e649415757e01b4555e8ad82ff752e2fa4972fdad66ed04',
            
            'debian:11'           => '0391e02ae25930697ee16ea348517ad4e53e574181ab1bd74cabeb045b4df4c1758c2d7ad6c31db98c2472341f067b3ea8f5f1ff32af1a84dc57821ed3be7c10', 
            'debian:aarch64:11'   => '',

            'debian:12' => '25f8cf6775e763db120927efb8f33f372c80257f7af117e628071c0dddf82950cfa76bef1e4a8638283816b289b26911019822030ef8d64020cb1cfe4d054eb5',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => 'ef9d4d0c1b4213cc34fabe8034a07c449e6831ea1cc5735c652d10f580b9729807dd0a27eec658cf165bed99150ba47c82704ae9633606e88c3710e6df06fde3',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '32b0c56f342e5a43348dc1e3d4c3bf2dccc25747cc042f660ead4c33393de397067037cea963441af19bc16d5449fa8329d0f8ec056100559d08b06ad5b9cc58',
            'ubuntu:aarch64:22.04'=> '',
        },
        'icu_65_1'              => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => 'd98fb1b3bc672d0d16c069f96469e20cb7638baea8eceb9148c8073a08da91535af0b10dd68c5d088a56a837f94539c9e40ffa5df6fa56ce6dd81115fdfedaed',

            'debian:11'           => 'b715b4421a2035f134ac8bcb16be7b16ec639a2c6c5eabe6c9b37aeb7335447e608b43dd8366d5d3b95f02b4025241bedc7c865e4b3028db9c93c27e893630f9', 
            'debian:aarch64:11'   => '',

            'debian:12' => 'bfdac0da635287f9001eba9b5e7b3dd94502cd4fa6011faa1646748721aaebc47f004e04182bc0050444698a9c0191588e01848907fd7fd92a60bba73649808f',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '2c60dd62abee05bcbfaea7ac5ceff91ed97a19f609b2ff1c094eb6ffee03af41163efe83cddf8697a11fabe75cc287c126b62ece4639def67b7893c47df71bfc',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'abcf9209a081a93a36ae5807a8968790b9523c86039ad2cc6853613155ae44136d77898ebaaae0626ed4927f2bae2b35520c4d22bf1e198f857f35d8168d294e',
            'ubuntu:aarch64:22.04'=> '',
        },
        'boost_1_81_0'          => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '00da65f7250712c0600133ed841e69bc4bee08e6e94d51f09f86c2d4d2447c8622bc507977b3226d88e864bec54369313e13f1754397e20a29fe570a303ffe6b',
            
            'debian:11'           => 'ade3f33bb6c027e51e692f1d44b77d67b2b115e8e790f75f73bb6f7b582f1f68bd8546dc9ebfcfdbb20de652006689de18a1507533e1e253edff7ed5a7b506fd',
            'debian:aarch64:11'   => '',

            'debian:12' => '25e815c74ce3632cb807a469157e97e5f1ce4429237c45f4a54d317585e794e56274ae6a5ba40ecb703a7c6f046c0f38e8d8659f6e4c35e1ce4b3168a6063555',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '308a8420807a933df885e21bc732b8c2c0890bb783535564cf3ba0e6ba85368e3a55aaf53048ed425816a9dda71c875171691783b7d37a22e89b659f83bbeb5c',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'cac73c09c82d1120c19de3cfcbf058bd96c6ecefd1069bc033b3862153ee0eac393ef0755344d2ed48c68fb6f29ae9846191f74fc31ce544ea8cd2e7f0e0d4d0',
            'ubuntu:aarch64:22.04'=> '',
        },
        'capnproto_0_8_0'       => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => 'e8fc8ad87ebf5301ce4835f1c708ca37a302ebe48c5b4d28a0566cacb6f02e87e83191f1007c51f344320b01120146904cd68bf4a4f57cdce431f4c7f2c0714c',
            
            'debian:11'           => '786e283c60956315c1081595681e3b40f2239d60f06ceaae1f6028fd2c56e84bd6ffd3177fb3277f5d189d6569b822e0d815b63d52bedda06bea65634979cfab', 
            'debian:aarch64:11'   => '',

            'debian:12' => '3073edc552b06882ecec96ee745717bd8b34726a3d521365f267c5129253d43b562a36b0b477563285a68c4508d7120d948c62c03b844a641b5597da9aa603c9',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => 'cfd048ceb736f3c29180d8948abb0f1407c209553e05806c840c65d09e3c0a069b7247f4863f5902280b15b50b3ff2d14b8a4dddc0c904fa800b9b09465fdfaf',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '889ec9435ccd4cad41d1f62128f9617d37ca51d8fcfb0444ed3b94551d08ac1dfa088e8054e70f4d238f38a1e2ca003011e4e55d9c4aae327f5c0973bae54276',
            'ubuntu:aarch64:22.04'=> '',
        },
        'hiredis_0_14'          => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '767e46398907f5fd74f60a9f13ed7fbf437d94619f884712d53e041719143cf1149cc00ceb4b756e1bda6edb613ac7146034a6d1ea69049337a375125c00a166',
            
            'debian:11'           => '026afd14793464610538ee8af5a25d344ffafd53e5066acc7d99f11b30c6e311f22d14305ef317c92eb182f29ee8275c664d8897b92e5fc5178ac7d5ee277a5c',
            'debian:aarch64:11'   => '',

            'debian:12' => 'e9aff811beb87b654c8f1ff9253432ce7fa3363c94a6136fb4e6f142570adf2c9b8382e8353ecfd6cf5a39954707e101619c2a51aec8800cbb0064aab8446450',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '5c73f7020ecb2cac27f71547b14c0e7730352f734e4aa28bd46e410d3550b68dd1bbc35a11b71ebf14fa16a9c2725ee9f5e0617d7bf82f9807f82cb0191ae492',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '00ddb1e8edca62f7ee55526de771501cfb5f2baea0db84b63475fa750633a726d417a4a6bc42a82e84e1a70c3cfccb89d8a74fbc2b8a740e8002af920391d934',
            'ubuntu:aarch64:22.04'=> '',
        },
        'mongo_c_driver_1_23_0' => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '4febefaca45b4f086d13cd876984bf815ecbd9cc5f41f866a46deeb3f90a577c35d0c0373c33f6fa84214da1dd0ef6b97e1d9617a7c6eae81118ad895b927276',
            
            'debian:11'           => '0d399fe40d00676e1d8ea070b22b375176ff5e01d74bb97f58d005eee9fd85445be413d23460593fb9f764f934e9fd34aab303727dcf044b8ea5edb64ee501fe',
            'debian:aarch64:11'   => '',

            'debian:12' => '13e3b5378781047554c0453872883806f885ee4b783228d5bacbcb7166334b34b08c1a3135519e37129985a1810fd47ea0f4e6986d54c2a4237e1c2d401ba267',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '6839e1a3eccfa6fa2df878ab4d3303ccac1d32e41d7708b8ed47a9c0a80a6f50ab7926b1b2417ec8f3f05da3136655f77cd7c18bc14ddc0adf5e78b2c5a1812f',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'fa475318332cbf4e59529455fa13b69c634405f8d166be7ef2c4c5857a290be911fce5828f3a78937c66d4c0af048f0202cc3d3f0923dcd769a782cc93d153c8',
            'ubuntu:aarch64:22.04'=> '',
        },
        're2_2022_12_01'        => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '8562ca33737929d9d6578078de2d07a4c1772971dc5d36714aed980a17dc7a65e1a2888083412726b44edb519956342be899d28d40eaf64008222c47e0756b2a',
            
            'debian:11'           => 'c24fc869faee3900451294549e73fe6d0251f69cd14d8cf55a991fa7bc051d7dadba19e3e3168bb9a5a68b0b0d29dd260d28a953e76301aafbb6159c0d1be1bc',
            'debian:aarch64:11'   => '',

            'debian:12' => '6db588a94a537fac7ab059a6a4ff82e4766109a18b460bc4e9ecc001e559690bfee9ac4c3256b5e9756df9745172d9f3728991fc14716af4d2ab092b6eb2c95e',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => 'acb38f492c6e9459c1a9f7b27ad5d9029815cf956bfa54860d0070f9b4a7ea3fd571d66bd29a0070a8fd2fd600066eaed61b9944d4dce561d1d14b8a10540f44',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'd73b3f898f9af0bc5da3b725347ed31b63be11576bbb6c1bd04b82e7529efb430c8ff8c8316126b02690663fafaeb2e0aa323203323742ea9b1b569f836b8e83',
            'ubuntu:aarch64:22.04'=> '',
        },
        'abseil_2022_06_23'     => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '',
            
            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        'zlib_1_2_13'           => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '',
            
            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        'cares_1_18_1'          => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '',
            
            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        'protobuf_21_12'        => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '',
            
            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        'grpc_1_49_2'           => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '',
            
            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        'elfutils_0_186'        => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '',
            
            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        'bpf_1_0_1'             => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '',
            
            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        'rdkafka_1_7_0'           => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '',
            
            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        'cppkafka_0_3_1'          => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '',
            
            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        'gobgp_3_12_0'          => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '',
            
            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        # It's actually 1_1_4rc3 but we use only minor and major numbers
        'log4cpp_1_1_4'         => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '',
            
            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        'gtest_1_13_0' => {
            'debian:9'            => '',
            'debian:10'           => '',
            
            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',

            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',
        },
        'pcap_1_10_4' => {
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '2425803e6aa8f7544cb66e8e73de64ad6be9e02906b39a19e95b33303e9968340a7cf78ec9ddd0ceb55f2c21a6044203bc242b62bb55ea06e4076b1453eea759',

            'debian:11'           => '285908aaa6941fab4eb3b4c8a987261c9b12a13edf28d658f322a99eee460ccea73e06cd3609fd6e8db7232a9f34058baeeb86b0f0e17eb6ccf02b76a5c8a77d',
            'debian:aarch64:11'   => '',

            'debian:12' => '28411c63b15b8efe83169103e773e89b23d70596f2dc83b956bb62c168ccb7e46360444a937885eaf7d82856a1c0bc8c278d2328b342784ec4d70ccec72b9f98',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '078a74073eed2b3412ad8c5ab1482cc75fb081b5bc48a3e6de8284defebdee7dcf0b0bd30c4ab04290940b5287086aaf9e4fe724e42e1c0587a897f5747a3c4b',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'cfdaa117f846647752a1b122683eaf742f5203b7922ea96b48303640316cc584a0666ec9d133df438ccfac61eae053b85b9fd1a77144fece5ba9005cbac58a3f',
            'ubuntu:aarch64:22.04'=> '',
        }
    };

    # How many seconds we needed to download all dependencies
    # We need it to investigate impact on whole build process duration
    my $dependencies_download_time = 0;

    for my $package (@required_packages) {
        print "Install package $package\n";
        my $package_install_start_time = time();

        # We need to get package name from our folder name
        # We use regular expression which matches first part of folder name before we observe any numeric digits after _ (XXX_12345)
        # Name may be multi word like: aaa_bbb_123
        my ($function_name) = $package =~ m/^(.*?)_\d/;

        # Check that package is not installed
        my $package_install_path = "$library_install_folder/$package";

        if (-e $package_install_path) {
            warn "$package is installed, skip build\n";
            next;
        }

        # This check just validates that entry for package exists in $binary_build_hashes
        # But it does not validate that anything in that entry is populated
        # When add new package you just need to add it as empty hash first
        # And then populate with hashes
        my $binary_hash = $binary_build_hashes->{$package}; 

        unless ($binary_hash) {
            die "Binary hash does not exist for $package, please create at least empty hash structure for it in binary_build_hashes\n";
        }

        my $cache_download_start_time = time();

        # Try to retrieve it from S3 bucket 
        my $get_from_cache = Fastnetmon::get_library_binary_build_from_google_storage($package, $binary_hash);

        my $cache_download_duration = time() - $cache_download_start_time;
        $dependencies_download_time += $cache_download_duration;

        if ($get_from_cache == 1) {
            print "Got $package from cache\n";
            next;
        }

        # In case of any issues with hashes we must break build procedure to raise attention
        if ($get_from_cache == 2) {
            die "Detected hash issues for package $package, stop build process, it may be sign of data tampering, manual checking is needed\n";
        }

        # We can reach this step only if file did not exist previously
        print "Cannot get package $package from cache, starting build procedure\n";

        # We provide full package name i.e. package_1_2_3 as second argument as we will use it as name for installation folder
        my $install_res = Fastnetmon::install_package_by_name($function_name, $package);
 
        unless ($install_res) {
            die "Cannot install package $package using handler $function_name: $install_res\n";
        }

        # We successfully built it, let's upload it to cache

        my $elapse = time() - $package_install_start_time;

        my $build_time_minutes = sprintf("%.2f", $elapse / 60);

        # Build only long time
        if ($build_time_minutes > 1) {
            print "Package build time: " . int($build_time_minutes) . " Minutes\n";
        }

        # Upload successfully built package to S3
        my $upload_binary_res = Fastnetmon::upload_binary_build_to_google_storage($package);

        # We can ignore upload failures as they're not critical
        if (!$upload_binary_res) {
            warn "Cannot upload dependency to cache\n";
            next;
        }


        print "\n\n";
    }

    my $install_time = time() - $start_time;
    my $pretty_install_time_in_minutes = sprintf("%.2f", $install_time / 60);

    print "We have installed all dependencies in $pretty_install_time_in_minutes minutes\n";
    
    my $cache_download_time_in_minutes = sprintf("%.2f", $dependencies_download_time / 60);
    
    print "We have downloaded all cached dependencies in $cache_download_time_in_minutes minutes\n";
}
