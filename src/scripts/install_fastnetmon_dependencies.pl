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
            'debian:10'           => '8aae751ebc5e61a4b48174ce8dec13dd403861e33122169b9fa3ee86a0586e9de73b88f2d35a719998777f2326828e196a75348fac86164117586de475f576c0',
            
            'debian:11'           => '01cadd9b281058897b605fe33ca7e2f60bd0e9e09b590cc82b044b061519845405f889eccc6a1a60bcd6669ea88e215f22c24e043a1a018ade6d2f1e6891a78b',
            'debian:aarch64:11'   => '',
            
            'debian:12' => '2bcf3851778a8e8463211304ae0ed2481a82c20637ca4db15b5da65cc6abfe92088b8c25986efafea21f4697f4733f391d78fe97d958868013275f180803d086',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',
            
            'ubuntu:20.04'        => '98060fcf0ce2f34863d2acc16ba208df7c15e28ccc4897a7a538cb1e36cb62114613574974095810c8ed6969c7f1a7caa42554f28629a5f92d634f0974963ca0',
            'ubuntu:aarch64:20.04'=> '',
            
            'ubuntu:22.04'        => '0ab99901c46feec327d6f33cc3e1a397a2ec960c411906234d98e525b907fe0dd3dd84894f28319df2df9703eb7ce9bba75ee8ebd7c1925c3c97e5db353c16e6',
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
            'debian:10'           => '21149f521f8180a76b000b4ed8f17d9194c207a5f6b38cf328c54e06b9bcd81b15597838284a7775c7d8bcc3bfe79ebd47808cf96ad86c122585d5a81a06e505',
            
            'debian:11'           => '4d7e66a9b9feab3a872edb76767af9eee68641af1c619242105df7fe45e65fdbac148f3944764399b766b101288c43441d2348fa3a1e8cf97f4645dbcb7e9ffd',
            'debian:aarch64:11'   => '',

            'debian:12' => '9aceaf30472289494204ba8439d276f6d5051a654970c9bf3c1f16119a55b224faa432e9696b8e628332553e6edd83270a00ab398427a8c3fffbd800e9bb4758',
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
            'debian:10'           => '06ba81829957e093d2d9985771fdaf86e9c4a3e2f8c9baed96c3fe6f65c3c8dc7ff0a7b96a3820b8827911d4db816673b7bf4e1652ddd19b7d0e7b1a5e80e3fd',
            
            'debian:11'           => '394254641cf93c5fc74a4534d3c5a7a13a54d8d979db4e642b07427de0ccc682a3370978aa32b32a9d9a3ee4239aeba8c99c2c088e0c5454fa7ddd8fc307b4d8',
            'debian:aarch64:11'   => '',

            'debian:12' => '8fac8dd7537228e01c005659538cebcbc16f4744c9144e55134a4c5c70c3cf73a6fab4825badfef621b01c5a7d767c693c9001b7fade6859227d7c19a594b173',
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
            'debian:10'           => '754621b68f63e8c4bc1d5a7bf1a62ffdeb7c9eed0d79a3cb7e20d601917f5cdeb0de668eadac70e91865a904a3d7b25ecda810cc7d8cea9221ba40df0c295d15',
            
            'debian:11'           => '5edf8ebfdfbe9c34eec070936cc9fd46c0f53c27385245d1a2f90ca8019fd10a546f8c66a513291800a9e7c794d6cd74efc9f7287eb0af7ce925bf0804154205', 
            'debian:aarch64:11'   => '',

            'debian:12' => 'e90ef9b9e4ed40653ffec85119181566377806f8f75afce2643c60a5eb25c67ac487093d09a34a7c5a392b112ea8d75c12af69b737feb7f0068dd929a9c32605',
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
            'debian:10'           => '81e72bfd99a4f31d9ce40bda8dd3a341e1c797c3c757aa25050ffb80452a161aa9d79b735cfd94985312d521e6365935e6d460efb0d47ae1cf340f0014036f4f',

            'debian:11'           => 'e2f5d62fc9405b571d26e2a7f55225b8a83cc63899d4835f5e848ac49997d038734b9b35d085d4c08e9e06474f5cd04dd3c0a334dbcd7d7dcf2835cfbb01ad5d', 
            'debian:aarch64:11'   => '',

            'debian:12' => 'cea65ae5acccb5d1dda2e091b647370133fe239666c6266bd689c19af5940b1aefd97c3028dcce34b37b6f7f6e2085a318db1e3ba67349a440c4b3f1a7d37965',
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
            'debian:10'           => '6386f786547356a305d4a88ee72d972988183450f16cc0a12d8a34215aa5ce7fd0e62d2e2fbdd296f99ce5e20165ce5dbd3b5f9a5e17cd66e66fc0767b398dca',
            
            'debian:11'           => '2d995f7dba66c4ede22d605843c04caf18edde2816da92c4a7697f1194dc3147868ada5b6bb25cef1862d3339cb8d897c5be7bba96080eb5939f2c08ba4e2dbc',
            'debian:aarch64:11'   => '',

            'debian:12' => 'b035df824f946e636962807cb2e70f5804036c15e7516117d4473ab813cc8ad308851a4bba622085388683b39c4f86d484f187a5350bab5f3f3c4374cdab3766',
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
            'debian:10'           => '7a7bc1fe1b2d8882a891eb7e772ec851b15827321fe8128bea7e8ae0e0776053ad0a28b9676f4e7308f15fc9aed8af3854f51ccf999cecbf499dc6ddbddd1655',
            
            'debian:11'           => '004e9537025537e3add2af8820aea580047a5c9864e868353a2f975161b11160841dfe3fe91d2c7df9b7c9c384caa6173e4c6cad3c1d965d3fdf6007ee29cd85', 
            'debian:aarch64:11'   => '',

            'debian:12' => 'a541e663f4fe13e4fb94a300dc9b03754519ef5ed9592f3b67670e54333a4d2b9d6c0f09e5ccb8a226911330e4023795aeeb9db6d95df8c6252391015534a57b',
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
            'debian:10'           => 'd9b1a60552b3e14fef713c98b9ec4fa4fe2294bc2632b6b1644759be001c561c190fc0963958165e6745cd61000dde84e0054e30c526c72607b80904f982215b',
            
            'debian:11'           => 'dc710bb30e34252cdd4d3c0d3d96e735c73c5c1b934b17285d4c78ecc89bb76d6a4ce7f35f634a3178d663fdf2902c3181b24ece6bbb139729c7ead5e287603a',
            'debian:aarch64:11'   => '',

            'debian:12' => 'f5e4e7938731f13a423eecabb3308e380b765d871a7c0b388229ac11a0b5e61b129204ce705c5b6168780022299942e738bdf18cfc4604b111035f19fce10858',
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
            'debian:10'           => '4f6e19d1294869845a923769aba77d37bae2cb17fcc034a57d58277b8e47e2fbed59bd28f6a904ddbe3d40b8f724c0f6c260b3a4b0e87dd19b31f112d7587bdb',
            
            'debian:11'           => '3ad3db5f545997010ca14af4324a6c432052ea89b21a2e65f7de2d929e1b2cbf2e89d2ba1f614da3e1ae990ab2b7f194f039892ddda90360c1e21f522f3fa015',
            'debian:aarch64:11'   => '',

            'debian:12' => 'b7fab5116b0b95cbd2b898ce713d8d5d7c7ddd9d053906144dc7a3bd4dbd9c31b10d89d8945df0ff2c536f15b0cdf6257d10b24a4431ca5da3057b57408afd46',
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
            'debian:10'           => '89bcf9e45e7675aefb0fbbf1a25dd2a0494a47d0e97fc8c37be4322dfd8fb2de7c31cc64786c723092da33c0bfca53f15d51469f99f9dc9461ae18903b91f368',
            
            'debian:11'           => '2fb20d392cd3d158498ec22af2f2251d1b339ad242622fad89ecf06c477df142c7bbb95803282c76ae905f84e50a35be3361e9e2293ae68e12ad225932903025',
            'debian:aarch64:11'   => '',

            'debian:12' => 'c90caa36d40ebaaddadf86affa75ad65476b9374297c88c4d2adc69f3958f4f6b92053f3ad22c863456e3c4f95548301ccebfb17b3859411919cc2c896877b9e',
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
            'debian:10'           => 'a2eff1db9d9e46af4b3cf0aa96c496b884e625611217f40df703c184b3071d72288a71d4dea299bd4d13d73734249b6de9d7f13c6faf788d10ad8fff49a3ca44',

            'debian:11'           => 'ed8dbcead0821098a463f327ded4d736a2f5f2ad677adc86944d2477db023d49ee22784478aebfda67d56d3b4415ab4c81be8ca89627c0666a3b72374a0a07c5',
            'debian:aarch64:11'   => '',

            'debian:12' => '027ffa9e22b33ac0d3f2c843b0a30c9ed938c30d1e67e06be0ca4d5ad7b16d13bfd238c1d870617d4ee60e6dc5a54cd6e8c3e9ba486009efcbf2e2e865909324',
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
