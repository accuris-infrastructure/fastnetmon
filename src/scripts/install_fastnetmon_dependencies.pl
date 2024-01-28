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
            'debian:10'           => '3a6b4da54c77494bfb42e3ca43076496a454567165423bdb93b24507a8c24d962b2319dbfb2a1611e18e349d408d355dc268aee4806b38f80fb7dafde5f777c7',
            
            'debian:11'           => '88606df69a5517de10fb6489b29fc3856c428508e60554cd906315f24aa72ed2ee1094968f6831faf976d8159e1167af9d7cbfdee659513e1fce9304a95aa6d6',
            'debian:aarch64:11'   => '7f4e33e396678f76aee2684acab98dfe3f3d801e214312d092c335f7165729610f93d9106b3a5e4de9c63fe1a1319403a202522562492af635a9bd852f6fe1fd',
            
            'debian:12' => '148ee880c4a570de52ca5f5452e0d29b70679042e2855f132ae23181b43227f4b9e2265604df1fb4e6aaed92e4ae90299a4aca7986baa7f6a40540d1f90b7a74',
            'debian:aarch64:12' => '7e7978a524c8144f861964ad12fbb7a75e39fb10e8be0b0de8e314852aa8b2c57f57e84db8489c3e35cd890b9c9f435dcbe73cfad22a00e658a34449c4f395e7',

            'ubuntu:16.04'        => 'b455b76410ad6d184d594a1f9b53d40a0b9d3caeff9fff9f9b11be083fd674cea7a0ddf1a1816fb07dbfe8d3ee2d9bcb34dbe59b3edca83f2241a2682a151e8e',
            'ubuntu:18.04'        => 'c63f598578c91200fdbfaa994d3fef61d2aec25c3c1b8d80e42f80d97fa59810f8d2dcdb62b6f1d718e1110348e0ddd919e28ce293336906f127e2ba5d7d5aa5',
            
            'ubuntu:20.04'        => 'd22517b098fea3d55e72b48dd59e111e4d7e14a8f46baa5b9dfffaf60f729f423ac0e16046ee4ed1f001f7761c9b405e9d7a5d63248d4ed99546de29f121972d',
            'ubuntu:aarch64:20.04'=> '',
            
            'ubuntu:22.04'        => '7712bc72d788ecf7c2bf1f92b613617c79c56a2471f9fdc8b567f80f210b2ad87bdcfebe95a77d1f113cbbf50f7dbff15cd0051f82ad8e21491b3fc69079a3af',
            'ubuntu:aarch64:22.04'=> '',

            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '3366cd870f02edd356e3cae36d073c4a82157f36a22fc6644e5b3e391a682f0f3a7cbc7cbcd0bfb523b9f00ab10619c6dc944b725ca4f825657a2807c45ab9cb',

            'centos:9'            => '',
            'centos:aarch64:9'    => '49960a76af5580b6b43361d434ac989b04224b1f6d6fe30585f8707791c4a254ed9f2fdda24b18dc3ade7100f252abf845a70dbc6726d32cafb051f5df61d95a',
        },
        'openssl_1_1_1q'        => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => 'e77e08b1d80504c535bf1211041846e2784604e37157968ca198d74dab157ba02055c670fe65a07ee857c7dde4a8f7ee85e0fde9c8752d8067f389042a5101e3',

            'centos:9'            => '',
            'centos:aarch64:9'    => '1f9c9eeee577a8a9f4194c57571d27570d7712e77a53e17a9a28ddcc51aae94d7dc84940cffaaa95b546358016fb3f6d0cd000a6fb3ad43353063acc77d2d27a',

            'debian:9'            => '',
            'debian:10'           => 'ed48f2cfcae3cf3fcef1918ace128511ec80067371fba4f7b8a582d61d067747e3297e2d356539bb5f41d4c8ecd31640b8a47cb5b2a926662995e70b3a2a4347',
            
            'debian:11'           => '8d850add822ecb0bd91345648f1589723db6c5e0da6c0f484df5b3227c27eed44221d55726583538ee2f85d7e6a2849e8846d7b557d687b2a224a309e0fcc9ff',
            'debian:aarch64:11'   => '8623045a357ee614a44b6ad3ea6ea1091936e6ad706fbda19b5fc63aa3e24694b0642d25d2114ee1e926deac841cc7a56d6192b6ded785de2edeeeaba1ffb48d',

            'debian:12' => 'fe3eb31dbd6abb4375ac7af31d152eed8e8223ef8fa1696910c3f9b6ef321ca5071d10fd46c59cd78c170e8f2381525b281ea136ca5f5d85254f66283d0566fb',
            'debian:aarch64:12' => '9f09bc2f252424189267546e16b682549523ceda22e26956cc505ffc8d2dedf9b2bb8fda8d022ab8df3127e80cfc2986af1474f3611a1fdd8114707d9ead0161',

            'ubuntu:16.04'        => 'f1a7b27bd18e8c4f0f73f1c15fbdc962286a352df6bc8b2370471ba4d131d8b1080aa0323f45b7caed6010f10e04c87bd3cbd9f716d26e8c3622469163e2f070',
            'ubuntu:18.04'        => '690a073071c6b6285fc667eb0af00a5cda825d9f13584d5195c8729b5ee4a7982516359d8a04291f3161a991ec4b4427a3f5bf15de6679a32cbbf0b9b5ccc71a',
            
            'ubuntu:20.04'        => '2caf54336ddb2913bfb6826f499fb7f2a03491b778c33eebc1c800adef51307135d64b004dd2148054ccfb04a44a378c1edfcade1c316b2dd19fd109851de5dd',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '7fd643dac330512941e066c051ac45b90d468f07dc71966f588f815528bb542b5bd0bcdadef7cb9c8f52121909af9c26a3ea18280e95220f9d6d6574ded1a84c',
            'ubuntu:aarch64:22.04'=> '',
        }, 
        'cmake_3_23_4'          => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '8dc0d2abefdd59b0ecbf1de1aa57b06ad9e4315220a87f00af384a07757c527ba8f39e2be34533b8c406683730b6a53e507e61beb7eced7a908fa2d2f5538028',

            'centos:9'            => '',
            'centos:aarch64:9'    => '4df98daaf2d0beaf81dfb31f1f9c1557bdea765b186b0f95576868b6dde3c15e0fcd54f3f39b425c0d379970a56ff503c01a00dddf99fe6707ff5fdcbc84049f',

            'debian:9'            => '',
            'debian:10'           => 'fd71bfb2805a0261c9ebf43865c9367c9f86508774c3e6c6101d1e1ac65ddd853b01ebabd47c22ea21d3053f902be8045137a937ed3562ada59f619db95d0ddc',
            
            'debian:11'           => '62670ec47a4216328ac7690bde3e6f64301dfd5f69ab0cbf576e85fc29c402ccf8ad79130f477221fa3f7148c85b48809cd10ff3af34e493198394a0250494d6',
            'debian:aarch64:11'   => '8a3598c6d48d29964aed64f36aec8224be17aec88e1fdc60c68a5c972d1dfb69c75dac5ea8592d24bbb3732c5b7979548deef35fcd2e0d9c087ef70ef3d87e5c',

            'debian:12' => '5296edf92028f34721064fc3aa4ceaf0ca733cf174990e0c8898b44eac1b4de2ac9901a2f807f588f53472d679a2940656fbefcc79a403c110d4374e1f5aa33f',
            'debian:aarch64:12' => '7f8ddc15da8b4d04772849de278bbee3165d2431202859977f4b14839b6c1dc7bfec9b956070c09fdb34e2678a77422e7395edd4bbc6a59f2dc032e0c5f2b6d8',

            'ubuntu:16.04'        => '5ca8ff2551ca7cd0ac09c937fde7588ddf5ff857d00fd5b4d9a9bec0953eea6755b45e6cd25a57e66773bc7990c7155785eb7259a08fd611917e12df7622e3ce',
            'ubuntu:18.04'        => '3762453aea3d3b3fc5b500612eb2f9ef5d959c238140e6f3f1a67167a21b5f6d0c848cafe0a71ec3fb501142040ac3683105c1e26713c6e5b728879765d924ea',
            
            'ubuntu:20.04'        => '4095376be2b2c3f59f3d5f50f5839ed6b7e7bb71f446f58046b14f709ff61988a93d2d43034df54936b53025e05bbe8bf3ab8131dfd55031ccc4c6fe8bd68d6e',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '4ec12817cfd77e53a5dbaef0eab6a82ba4e478c0460a1e395a787a145d18794045eb1a2342794f82affc25ead8b8c4c1473294c15a4f3c8251c44abc9e2fc153',
            'ubuntu:aarch64:22.04'=> '',
        },
        'boost_build_4_9_2'     => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '58ff1e9a9e4c4e2b6f50e48d438e867d38a48ff6b3978a5fc92016a0ad260ccf95790aa3010f37f235be02af635ab05f4926c439a57bba85ab1a03ceb586a8dc',

            'centos:9'            => '',
            'centos:aarch64:9'    => '6209bb562cf34ad65e23af215c9aab6c11501c5f66558934bba0fe75f528e8833f137df0aa62b0b739edec5efc0ec0858ed22249fb6965b5d49c1000ce67e0de',

            'debian:9'            => '',
            'debian:10'           => '67b86375f91fbb4fec61df73d2c1ede9ba2935b4a584e00c784cf9ce5f4869aecf0bf027422b6d99e8e30d84f2b292ae3d5302e2150fa5a35eec6a96589e22aa',
            
            'debian:11'           => 'f8e0f8f6d82c02fda0692da81ff84bc3bb11c7e38a913f0eb49db809734e52ada80f24edc59065843b1d3617470c1c59b53438c66dbb425c32f6022991ef9562', 
            'debian:aarch64:11'   => '428656685b880785ecc469324dc6507a65d6bbdeec55bd3b28d44a628654316af317ca78b888e18a2ba4fa8c366cafa80e1cc5a6152b310b6f9c95c8573b30e0',

            'debian:12' => 'e5c6853c7b29c0655a406bd34d6adc7d0614a04cc12cbda450174773607c163d2073c366099d4dfd386b8cbc7c8a6e9c90415414b56a7b6372c1004bdd15b5ca',
            'debian:aarch64:12' => '7bc97190a076501cfef0746ae434f3e16ed46219bd72efeaa0a5d183a571d4f76b7748287fa55d53ffcc29a4d9d4611235090db8284c927776e7f72b80f32ec1',

            'ubuntu:16.04'        => 'c606812ef72ae90107a2772a207aca042263cda80cf70d6793ad22142bba7226f275e37b9248aedd2e7723f2170695240383ead58faad6f76adefac059764f36',
            'ubuntu:18.04'        => '0abb7f49c044c0d2d187200b27942e80e31e06129f5b74d474d4927d1207feb0f889a0198cbd702a104939a48b07f8c070510d09f25c03f1d3eb5778b309a681',
            
            'ubuntu:20.04'        => '143e7c72498b496e1c67d2b547c6b1111cd3c574c0c0264228d870c17f1df85fdc1afdc7a19d5fb052cb3cb53304e03f46ccf4131cb184589568640c266b0bb9',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '9624954a8c8054334d3ed736b482b09cc4881209b91539c778650a101d3abbebe3888208d79061fba5bedae28b24ae1f1a429550df1e98988539679d90ff956e',
            'ubuntu:aarch64:22.04'=> '',
        },
        'icu_65_1'              => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '3cda6e78f7160462d620e09b8a9b56587735d5c8ce66ec4cf97d3b2025144871184d725321ca84bc2bd8dad4d89c8d87948ad0dc07930552d9611e55be258360',

            'centos:9'            => '',
            'centos:aarch64:9'    => '6193268cb31f398414fa5802243c24438553121b5ee0e155001689fe0ce2d579bf569c54b80095609361088bf9ba2307fa0b4e0ff80a5ffb8cd63e19d0581c71',

            'debian:9'            => '',
            'debian:10'           => '27c8d78336e0eb05b836a9dd48e276ee1be744bc9aec76c8df82755957cb61f3c06b3cb83da233c8b5fd48b3de287d5a33fd1bfb68b735b771bd7b13ff5085bf',

            'debian:11'           => '8e904a62a064799e38d8a01505abcf8ee80b4077f6b6073283a4e12d10e355a91dd8ff6ab6083a1d62684a16bf3557a9db3915c29189fb9e2448e5d7c639be2f', 
            'debian:aarch64:11'   => '3827029b4d1010acde344983c4a9823abeb0e2563284347723c84203ae9fee04909540bc61c03b401aa76d3194b6da76a7e4aa372ffc37c392abd231ae146625',

            'debian:12' => '859441a88f071757c4f68e1e3391d1fecb474035b9980539d4c87fd3be9e6ab128ea2ca98dd38fef8c948573c73884558917320ce9bb68c6aad7385166ffc5b2',
            'debian:aarch64:12' => '81761c82280e2b1627214edc3677b821632968d318c1dfa332a2e8ca8ca407de7364d60448751fb36f6d5e7ce9814016a9d801f5a372407e69e9dc8d0cff6ad3',

            'ubuntu:16.04'        => '6f90bd7077badd53abd9045572ef43c0590802e383397e8e6af238dedda00bf67b1fe5ffa48b66ddcd9d890761917c89c8e9dcb68db09521eb7d141324d0a9e7',
            'ubuntu:18.04'        => '32ab5e2c1a381319d00ac403994c8ab612e33b7517ae83737dbbda575f78a9ca6c963d2fdcfe753b5883df3b1bffea0fd357b7ce6f3cd4d5c9a0b4e03507ee7c',
            
            'ubuntu:20.04'        => '6308eb56bc5fad957e283db18f61eeeb01bac7946eae4282f885ebf200bc5c91865ddc83e203df85d0b193321b7735b327340ef3c51af176aaa8990ddbc11561',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'b2b496de53b078e5a1c3beafb01170d24e5017a56388269709b93dc611094f07dd39033d84145079aec67234906670936aea79e217fa87ae532a7c5a4664711f',
            'ubuntu:aarch64:22.04'=> '',
        },
        'boost_1_81_0'          => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '3f3049569648ef1ea4fbf532e0e01ac22231844085dd052261bb282c0e08321a938a0d95e5ca320ee833ac696d2978d894ce3e2180b9ea77112f89d797325745',
            
            'debian:11'           => '3f24be73f497c92ed38277a2d18fd914911aa37eb82e47b6a0dc6b7a6701de1a6aef0af78b2405788f81b7559712ba94db70b38d3601ac3d17ea7fb88747f5ec',
            'debian:aarch64:11'   => '77dd5e2127bda90935904f010c6568a9d59cb24d09cdc553e54cf4a2630a386d3c63a804b0a5564a4d1c5a2f66376b50cda6bf8c714f561e9ea78268342279aa',

            'debian:12' => '208b2e02f684a1d7c7e2e4cc7bb9699f28cafed2cc6913b3074738abefbe209720d74f0be7830bb7095315323c7468805efd03858dfbfc4509492de2dcc62282',
            'debian:aarch64:12' => '7ca54a31f0a5b0c66ead2ed38e3820b3ae5ada53ef1d8a35cb6e56ac2e3f5974be1df10ac6cc41174c380ecbaa7341dd0ee911f9f6299b35821a26214a3a27dc',

            'ubuntu:16.04'        => 'c479aca1c48e327d5a53b2696e23f29f564e5fee6eec47761988e36823c914e98562c03ecbb822e5029c0649d7e34749dded159c25238215b49d70b92637283f',
            'ubuntu:18.04'        => '71ae393a3592900cf1dc23dfb7ec9f14a4bbe4c958ef1fa2741b32cfd802a9b62854fbed4e86671e3b2cec07889bd74dc9cd6a39abc554ee2e10bfd0a519e40a',
            
            'ubuntu:20.04'        => 'c642b17f41ed7e092f2965fff1475f0219548993ec39fbb22b019c08f8edb68b3f876641ca825496950408e9f1851e3e078557a7274a48a45ed0770e005642d6',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'ca620796d025b8ed860e00229887f3e7e985bb098d613a1ece4ac77b4643c62ad52f28eb6be702a4cdcdf4d7b3080492a43c424c0bc2e73c1195f0bb031fec08',
            'ubuntu:aarch64:22.04'=> '',
        },
        'capnproto_0_8_0'       => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => 'acbd30dfc3f6317de1ad5183fc552ea0755e07c2fe60ecd33cd7461ce4d953491d1d3abe3370127d4009f2a69398d46a5d800e5caefc659c06742d55c15dbd83',
            
            'debian:11'           => '5ce7fa644ce0c80343eb13f109e2032dc3f5dca8da10c71d2f0c9f2bd47665df037618236b370b5448be48357902ea6860e2e3702f4953ef877f0a33b64e0af6', 
            'debian:aarch64:11'   => 'f33f9331bd2660a7ef9b924748c01eab43e400902e2f24d5766179a0e60d7be0e68091bbf3e08224aa8056b82aeef2f26afb750485f3ed805bf801f8f990c5df',

            'debian:12' => '78c7b400c5e62a66660dabe212b2d73b6ce845d18545b68dc90014960f960f2093a676e9857dfe654488c9798c2b30fd6f4c9ac9c2b4eeebad5fc0e75fd40f13',
            'debian:aarch64:12' => 'b233bcd7ce79aca3f4e6e6f50aee7d119fad6347b85f68820e5894ca2d0dae325c47815f1c416b5f17afe0d1cbc0b3885a4939857fd690506ad62a3b6db112b5',

            'ubuntu:16.04'        => 'b965ee209809319581369b96ddaaa1917fb0988325352ae3ec6b7078b8906f37e9c9319ff38d449ec4ed00c2c53d74f1cff02a566dc3cc2f68cd8cba97c409f8',
            'ubuntu:18.04'        => 'a86232387c6ac87190a52fa600c64381f89695cca274db995cf991d50909927c33a5851a623dd70ccbb055079a6579ad12219ecde06b3a5200ac48f60de1d12d',
            
            'ubuntu:20.04'        => 'dce98838b9ad8798e519a9c059d5938be635480c8d5d69b21cb0c7f6fc1b3be493db319f3f84775588ba516d940372d558d67cb7cca4200b0f4c50c63435cff2',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'e1778d55382491dc12e73df798aa66988be6177bb4c7421eab99710208e36221784453457077e308016ae7e6a8f7e2a82e38c1f8e16d140346b07ba4e614f021',
            'ubuntu:aarch64:22.04'=> '',
        },
        'hiredis_0_14'          => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '4c11a797f4bee2fc0abeac6ad0e03dab7ed8b1fde58bd9283b15182e2d5109adec980d898c683d5167b88560e141a49816e16109fd6bb5b76a5272b74a4569a1',
            
            'debian:11'           => '6ca40c0dbdd88ae728a2870cd1c9af6ec9bae553457e7579bf4d2e0e103be63a0c6b98741e2541cdaa2758a765a12c02ee390fcf147a6157d76f7488aa963b77',
            'debian:aarch64:11'   => '97488d306097b48beb57c4f054c6263f3b09d22aab38ddaf2370126e6d1dd53b35335c2406e999539023bf50c98cb4993c5e1676b8b16bad43974fea528d5f08',

            'debian:12' => 'a01670b858d63851947d60c01523a3d2b0365a8e24b8061193509559a6a078880f8c892ac81e8f69d198afabc2858c3bbedf177cd26606cb7a4f04d2a4d4bfa0',
            'debian:aarch64:12' => '579b57debdb04e003b912d03acfb19526ab923f0cc41d82232b51466ff9696b9b2bbe71340cdb81b1076a21f1ce8522cbe7f4ec6710307edb5ae419c2ca9af5e',

            'ubuntu:16.04'        => 'bb24f5453e47c6df91d158cfae948fe7763eff274b317bb545b8139159ae8b7ed865a075df7f7e7ae27139d247d448acfb04aef20f04b762bb643adcd3d36e53',
            'ubuntu:18.04'        => 'f4fa297699ac56d593075d680a8abf3c85aab6b19e347b7c4c2ef3ac17bdf61ab2d33c09c76a12427c28453493d7c6cbc1137ff99e770e9c88410f1b1fac52aa',
            
            'ubuntu:20.04'        => '9a1e135d7e73235a751a39df3861be202c47d4abb067e8c18e9a6072f9f2cc179684da6c783b8e65680639b34cd83972d6a8f4a88eee699f123cd84997cc38ec',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '35ee4c2c28255454e3f42a8f6c00ba8ba803d66c5a73e3dfbda8a66ec99b96e8a4ea70125ba69ee50893eea1bd632a1644c0271cd11ab433d467243b2b290194',
            'ubuntu:aarch64:22.04'=> '',
        },
        'mongo_c_driver_1_23_0' => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '2b4f6812aa19735af5be0b8d1cea580564749c28cfccd18c8aa8184f3ed3d1e567f6d4e2ace765ef190bef28a7bca319ce1c3980f3e9b2e46eb6ec2d3d29b627',
            
            'debian:11'           => '68f25cec16382b3b872640572df74f74db4c01ef69f94542f46bca230eda5194665916158fe2ad7ad94c5b52f7d2ee92daca78b61f9ff9167e4646cf7bee3bd8',
            'debian:aarch64:11'   => '1ee74e4532564c3f5bfd9caee6846bdc81878d01e78235378703c7360537da121e8b2a4a80bd2677f6dae7cbec732460d351932fb91259fd03dc536baf33b6fd',

            'debian:12' => '179fed21ff15552cb2f3a1d465f434742eda139977b344b8ad6ce98f52c8717286c8d51e97f17ca214b565dacfb845c194c6f1df80f019cd59165d9ec40c5f92',
            'debian:aarch64:12' => 'a1d0de72af66001c57f9cd77e45a1648f40f2e7ee8dd014f4c519125651c36f288296e3e4e68082bfdf8181c722d06a628a0b6771ecf0f7061f0a4cd7653e1f1',

            'ubuntu:16.04'        => '167d269e7dae1e93ecac671335d86a63a02e112c8d2bd52c02cd90bbeb6290aff646ef2583c8271516f4a60be1b9462096e73fd63956e11a2ad48416e9e4c5bf',
            'ubuntu:18.04'        => 'b7a9a4b231d95c5111b5d3908d4ae3f9729e619ef390c9e4bf3756857788ab1f24def12aaa93057c1327b2b9796b979ee1ad7be05f96f6464b18c1f6690ee02f',
            
            'ubuntu:20.04'        => 'edbc46b04d6baeb731aeec0ad54bb9becbc5a598733480f010a7e8f48c9088da338c4449fe94aba2fd86f34d5514005a5281f5e6e7b49bb63b55ab83f0dc631c',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'f1844f8c3283a444cb186728389eadc66fbdaa13197c4a6adf8abe9d9962ea458c8acf4147df839bbce86e5e6f9b082e6128138723251189d77d8f238920cf7b',
            'ubuntu:aarch64:22.04'=> '',
        },
        're2_2022_12_01'        => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '05ce0c08bb5fe24fbadb64091315257bad52179571fc7670ac18c54e5ba98de2ecabd49d83da0d0561fc29276c9ac02fd98d0ec288b020533003034243358682',
            
            'debian:11'           => 'c81c8b897118cd591449321eb6ddd790b0d3ceb71d41468267f7d01feac77eb69e3529c9efe644bf49f960c546d0e18174a1840ff65b238e2321bc5db1acda9a',
            'debian:aarch64:11'   => '1836f8647f42898e9834ff9028714f1e6c3627bda1b2668dc3d832d7318e5e7294a7e1ec63b3e6a60b1bb0d9764d0e60ab807b647de634a240a2dd96a9114216',

            'debian:12' => '7d2a6cee2046a886c3f78b7772f73cbe017ee8eeefc4ae4b64ac7c0d78af326e42bc99158e915475926bcda21554d0ad41bf8a91a79e34ab328eed3300a84141',
            'debian:aarch64:12' => '6a3e92b5495a2d570cf62ee107adbc947d4cebd8cb706d162866f58092337d42a47cf4eeba5c78304440ccf467c327ea6b5cc06df015ec59143ff3d6247e1f36',

            'ubuntu:16.04'        => '0f97177ff035746815a379f2fec5128ed3913ff189eb2a728c170e5b82c044dd814c8d15b2cdeef2c4de96bd9fde88730a335ab925128a4faaa9da01f01c3b16',
            'ubuntu:18.04'        => 'bd4338286e807ac15df29c5e7c416a0a5c1ee5d1fc349bdca98e76b929fccdc13c63550904a47a971c3aded120a92f62c778cb07aea9674d368a50f4e80a9980',
            
            'ubuntu:20.04'        => 'ee9d3a1765db7d439b2c08e3c64ee3740964e5115198c5f400e272828d54551b2a28c956348508cb59890661287aa1d80461bb4df0329283ca077723b70f5fd4',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'a2153725fd06466d30ef483ed2f5f3b6303e53b21e2b1deedd2fe9848463d0487ae16fad0d3d292367a4bb28c69b5e43fe706e4d2cbf94c29eae256c36160503',
            'ubuntu:aarch64:22.04'=> '',
        },
        'abseil_2022_06_23'     => {
            'centos:7'            => '',
            
            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:9'            => '',
            'debian:10'           => '6f3568e19e6612a4b250e8ee0aadca04b45ce239b669b4d1abcd8d7613e9579df532877ec18396de5b7aa872610af0141ee358d4e4572d1fb6c71f18d6b4959e',
            
            'debian:11'           => 'a379bd91f97ac683f2e989473b77357630ac72b5e0eb00cd5c983d4c2aba653337ecd3f12c14ded3db667f14878364255e2159dc968963968328e1ff22669311',
            'debian:aarch64:11'   => '',

            'debian:12' => 'f1170c74f8fd0f0425e2fb63039280054aba0b493c36730ea4bddfd8ff5dbc12469281db1b9c3c7b5c9a215498976ff3f541424792d07b0108b3d9ff09bcfe60',
            'debian:aarch64:12' => 'cd33ce1b137ac6f9d6231cda9c180925564c8d6308df4c4dcb8c775432970bde04cf87c1bcc782eca98e7f85630ccdbcb4eacbdbf3494e7eaa3e7dc7139254fe',

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
            'debian:10'           => 'e9112414ab09958ef00acd6a7ae9cdea9fbae048a7f35a08c1e59dc83a75cd8f13e053e48945d245a955c1839fb6e4f2a85e24c8d8affd9a05275277d1b39ee3',
            
            'debian:11'           => 'e9d61ec7724358cb52afcf9fc24b2c3a820c47c3143086489374c5840b60b462c4bbf746b659bcfdcda33365cae0ebeecd89f3cc2c25a3464633d64bf46c762d',
            'debian:aarch64:11'   => '',

            'debian:12' => '0b03cd27c9227729e1dbd7037834ef59100ac044a3dd2016338b2ea93a67d30bc62e1797360d1a5be8016510433b0fa30a603f139ee41f5cfe08f1d1e1dc0d94',
            'debian:aarch64:12' => '083e5bdbaa6de9e0b840906b0bd370e63e411a2a31f8c9e389d11c404c90b67d5f13c885ebe4fcdaabcc7e063d3251e1d904bbdb9f20455cb6dbf0c0cd03ef02',

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
            'debian:10'           => 'dee0fd9eebd1c573843a5e7d1a4b3d51ec6952371ad4b5552697d8362e813bc1a0aaa4b8dcfd10035e2faba47ca915e04f74f1f5c13df2e1388ecddcec949862',
            
            'debian:11'           => '6cda179c5ab6df4ec20c31515ec8d5c61140d90c30f8c123e20390338d2db70bf574ed9002509454348d4d69b1c0cb58852b063c9e3e7fbf6661b20144b85d4b',
            'debian:aarch64:11'   => '',

            'debian:12' => '1bbb4a47884d8bee7be3ad7e53fe3465fe357e88ec825f8e1346d4a77e9f7a60825f48f3c37819e4cd76056664ee4bf8bd8bfc958fc3915d55daf50f4f962825',
            'debian:aarch64:12' => 'ad3ee98b12af250a606b678e6898665060b0e6037c5b9d5829f28512e0fdd9191ba4cc2ad2bc24078634504ec6b0762344d087a8773f325849760803d43e4cdb',

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
            'debian:10'           => 'a1ccaa0501f38b132d6d53ae37115ac286b98b1b3b7ca13796b77825d728948f0b726aa7e788c3b43f8f684612594025dc04aceaf4964c244f880ef825643387',
            
            'debian:11'           => '3bc9bcbbc56f293a578a94e49bb6797de3529908ef393d6cb7ded9cfafb552ce08d117758f4e1924b7eaf84e6332a6bf8f70e68e4cdc4054ef8b0d30bf7dea68',
            'debian:aarch64:11'   => '',

            'debian:12' => '7ef6a1040e7aef5842e9faf325b047fe3fd13b747636e900700d57d047accbfd806cfc68d872b8d03fc35df1f76c2995b10befa8ce0ce85957a5f9922d32183b',
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
            'debian:10'           => '0db740d51582c69449e07d0ca5154fc4928f50d032949f75434abea9ae5f14e8b358c092e711214803659bb5fe411f14f7e0ac20e6eced6e6d3ada6a8b336c83',
            
            'debian:11'           => 'df4b6401382b87bc465e7520210f1c906098ad2310c30e2739d52d496609970e6eff63078c0a5c1e1a85c5359ef6d84d71197969a07782ad9bb2dd19548f3334',
            'debian:aarch64:11'   => '',

            'debian:12' => '5a7bec683aa85062f515225b8dff93698dc39a83e660a39b57be08b834fe0324255aefacf9bf31e11dd9d6a44b4f880023797d5b0c4858263d1bdb367e73903f',
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
            'debian:10'           => 'add68eb371dc43e5330c4c21dc9f6781ad5edcef0bb1c4869cda7eb37b56b0cb28fb8ff48346bd5b14853eaa5e319c149e66487f71b3aa1d95961eacc29c9744',
            
            'debian:11'           => '22c02ef2c002a7b63163238a2076800cac108fe8219bced478bfe0817d4c70ba7247ba76d0de2cac32b0d4196451069c63708909d59186df8f21fc2dc1702eb9',
            'debian:aarch64:11'   => '',

            'debian:12' => '0dbffa52eb3d6c232c62de65e2b74f4daaa1d1d82616e1b64e4a39b725bad8f4d912164d50bf2ee0455726ea96deb1594754c5b490582b1b9e27762c9a7d395e',
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
            'debian:10'           => 'e15961bb10cffb49c595827e9302521a2381919ce5f023f7bbf413058f73f9c316c380b9bf448ac30fcf3cf87e78972676df9e9c2cba57ec102fdb1aefe99b12',
            
            'debian:11'           => '2b9555bc2c18fb6b6d449c0f0fe8f835b54099d526b4a6c7e1581f201a51bfab02f68ac82c764168f8fa2313896abbb6fd50a756ab162bb6f47ec4f5c6252828',
            'debian:aarch64:11'   => '',

            'debian:12' => '4b6b07476dc3c3204651f28dd30abcbc07333e0accc5b47b0e92f5a3f26a3ba5725b5dc8cd54c08209d8f72a73013344f3e9960b9eccc826b59d8290fa5bf0a2',
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
            'debian:10'           => 'b5b792a674e0353897e4b4a3432b54d05ab95722370b3384131cc7f853ca29b636ba61f5035a4bd81dc8ffd58f1023c784ddd056ee021f4b49ded3e9db823c72',
            
            'debian:11'           => '55062b546aa36ff8db51750d1ba7f27bec170f804fae4ce2426d0e24040af507217e5ce950d314dc1c73be5d33bf3a5acb8eae09626d86e59fa686ea44630396',
            'debian:aarch64:11'   => '',

            'debian:12' => '08c5031c08da4e2e6a630c476051d245661af03a51c3635bac3f35adb1ba7a7263f7ef22a53aabd6e52f14bb6d48b9f158f3f59acf69b26d31af832191919831',
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
            'debian:10'           => 'a9dcb4985b9d880e6a1857aa5050a023d4aff50d1d5f113d3f7961f85ba3bd3840f9e4f561c16df0a84eb2a730772489595f862a4778546807bc890d1e36ea60',
            
            'debian:11'           => '42353192bea405bdde76bebdbc3631240079d63839fef45dde360ab0e5cc140c9fa495c1bd25a08a6baeea4ef2852fbfdf9a390b56d7aaa97ee3dcfd11f9f6c4',
            'debian:aarch64:11'   => '',

            'debian:12' => '9eb9df0cdaa8dca8820124b5d54683d986082a59ca2cbcde4861e18232f6a67b82ffa33d2d7b218fd287090d3e2531c4ec483936b528eadec6804197b36066f9',
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
            'debian:10'           => 'e0ec83e7fd8362474917ba1563ba3aeb3ccd01097f88a0f1032b57c1929f30b886accf448fb06fb54554523d1764c16a09d0db8156d2edfa7b15b533d19418e4',
            
            'debian:11'           => 'd754c303f8276c29671bfac545c8e475ff6e0d4a0e75f9b6af04ab5c61a75b823433101b2b1dfe7fed9d7ef46fb8a5ada70bfb1b4a9bb6849966bb56021f002b',
            'debian:aarch64:11'   => '',

            'debian:12' => 'e82b5e58cd994fdf8c1dd6df69349cfce07545ef52635c154d0bc355b72f9e75396144dbee7f319ad4cbd165eea3657d868bdf16e7d265e0e370a1795a830b4c',
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
            'debian:10'           => '670c64c7c52388162e699ef974704d031a9f3b73e2260037ec8107cdcd00cea9b6179f840fccaa287c5b1770ffe3464f9545b76e76794c349b5b3b83a4c981d1',
            
            'debian:11'           => '0dd3ecf33ccdf4f069cffafdd35f496ff4965593e4bfda711f00b853f6071f97173e6f36f255b1d409eab6f086d328c7d93442ae8d037a9e760720e2c78fc516',
            'debian:aarch64:11'   => '',

            'debian:12' => '15054eeff465a04bb911c109d32ed45f24584603643780562cfa0eab47db563d1d9f94174efdd09131d67d10c07e72ebf8db49487a39c807e734796e90cef22f',
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
            'debian:10'           => 'aec32e10b13a6da79022f4535c0f4aa5fbbb24be9a6caad6fba8e1dec27a6264bc46d96a52f181519b0257d5d1daf00abee38d0d339a31dd65526db63c0f42c0',
            
            'debian:11'           => '7f64793dac5db1fe17ee8d5fcd40a826b43c9866a8ace96143eec1a5caa367e815c40efac431c132911248ca660f3a5a0d3cb6cba0ff5904949b10c8412aa110',
            'debian:aarch64:11'   => '',

            'debian:12' => '518654440ccaf4a1aa4cea365a9382b61627447627db6a4148d2ad4f2a0696e9d533ee9666b58cffc2708c21ffb67c4d6a0cae49203ff4bd1938eb50334c0cc2',
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
            'centos:aarch64:8'    => '8d78ee65dcb571988b2a94304c0601656d826d96c1c6b63eeeaf51db07b8947de3e0b874a311937e02e8695e82f15b0c8225084c4c4d7e9f229fa8dcab77c51c',

            'centos:9'            => '',
            'centos:aarch64:9'    => '95f832f1a186bfb05251eacd4c45700d2809f9eca4c0b9224631d1e3ab3089b772c397af6f56b267d51689cbbc11e91ccd7973092ab6c79a8429f25a426ca6a4',

            'debian:9'            => '',
            'debian:10'           => '41141b3bd7a33127d20bb5a400c6007fec432c0a9048e6f53c66c026972e9be7a91e1008c53534222e5adabbed3d02c3e8780fc1e6e9c45c39465d75efce66f9',

            'debian:11'           => '398f92099382c570df04057a93afa3fe4a80d40115b3ce8c898f9d859303f1b4972220bf13e44d72b30c4ea2287d6875d8831a65b9e17b5f62ce4c0c70dc48af',
            'debian:aarch64:11'   => 'edea9c2a6b55f166bc1f426cdc602aa773c99ea98b1fcbcdced628a6b43ddec29a62ff89e96d836c9cc6d7a6783ef3da8bc621f64d1ee429482849a8e4b2a160',

            'debian:12' => '2b5070f61591555a9c955881de229827bbf9f4fd29143ad6f38d67bb4812bab7e521a10d61cc2e31b635e89dfc8970b62bb91ee1447df159f869baf7c379b768',
            'debian:aarch64:12' => '329fb7592e1411c084c8d6f1dce6cd5f9c0732feba1d7058bc8b1d83e9d3db24ae7c1a3a5938901b5c9d104fa321d0c0907c7682a257b4f850429786f6dfee43',

            'ubuntu:16.04'        => '9c7768f34e3488ae0bab6f6ee9511011beb2b75e0cf5f6e2753792f574386ea53c2303166479cca525ebf46c7b320d256d744d0d7efe71fce6688a0d0eb0195c',
            'ubuntu:18.04'        => '540cadd6413d9df55a07e7ad3faf0b294056aa90cc9845f7e90b68dfc9eb2f24e7855931e852c2665c7ac4051d990e0cb087345373cb3636fc0da2543f71602d',

            'ubuntu:20.04'        => '9f1d32f2f9dd7ea54c8d9068cf4100e005c78faae9aed10d719fee74b4bd84701b32cfde3ba24e75cfed0e0949429a954443d9aa0268efb88a2a9747b7fad58b',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'e2f4d4de50770f3d3cffb4534fa53145f0261cff521249bef825094a046418a8b13d92a11e856e42f3fa54b53843a5e8afd4a1279e9b0277a62661bae93dc147',
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
