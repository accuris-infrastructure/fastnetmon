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

        'clickhouse_2_3_0',

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
            'debian:10'           => '3a6b4da54c77494bfb42e3ca43076496a454567165423bdb93b24507a8c24d962b2319dbfb2a1611e18e349d408d355dc268aee4806b38f80fb7dafde5f777c7',
            
            'debian:11'           => '88606df69a5517de10fb6489b29fc3856c428508e60554cd906315f24aa72ed2ee1094968f6831faf976d8159e1167af9d7cbfdee659513e1fce9304a95aa6d6',
            'debian:aarch64:11'   => '7f4e33e396678f76aee2684acab98dfe3f3d801e214312d092c335f7165729610f93d9106b3a5e4de9c63fe1a1319403a202522562492af635a9bd852f6fe1fd',
            
            'debian:12' => '148ee880c4a570de52ca5f5452e0d29b70679042e2855f132ae23181b43227f4b9e2265604df1fb4e6aaed92e4ae90299a4aca7986baa7f6a40540d1f90b7a74',
            'debian:aarch64:12' => '7e7978a524c8144f861964ad12fbb7a75e39fb10e8be0b0de8e314852aa8b2c57f57e84db8489c3e35cd890b9c9f435dcbe73cfad22a00e658a34449c4f395e7',

            'ubuntu:16.04'        => 'b455b76410ad6d184d594a1f9b53d40a0b9d3caeff9fff9f9b11be083fd674cea7a0ddf1a1816fb07dbfe8d3ee2d9bcb34dbe59b3edca83f2241a2682a151e8e',
            'ubuntu:18.04'        => 'c63f598578c91200fdbfaa994d3fef61d2aec25c3c1b8d80e42f80d97fa59810f8d2dcdb62b6f1d718e1110348e0ddd919e28ce293336906f127e2ba5d7d5aa5',
            
            'ubuntu:20.04'        => 'd22517b098fea3d55e72b48dd59e111e4d7e14a8f46baa5b9dfffaf60f729f423ac0e16046ee4ed1f001f7761c9b405e9d7a5d63248d4ed99546de29f121972d',
            'ubuntu:aarch64:20.04'=> 'e1845b0489ef0ca8db291dddb594310bfeec3b8c74287fc4b574df8f4e9b1677ba93762e39c0f292ece3a360ac4e2d655ed6fc7aef462085017366ca47e5698b',
            
            'ubuntu:22.04'        => '7712bc72d788ecf7c2bf1f92b613617c79c56a2471f9fdc8b567f80f210b2ad87bdcfebe95a77d1f113cbbf50f7dbff15cd0051f82ad8e21491b3fc69079a3af',
            'ubuntu:aarch64:22.04'=> '0999826a605e2db741a77dfcc12a41118cc31f85f4e1896a58dbb48eb349378a868015ea1693c18cfa8eed4613619aef5fd0d7983eff6e9fbbedabe7ce7e2677',

            'centos:7'            => 'f5c70ab2b9a5effc67839fa54f3a78e88a028187722da82d1186fba82873b5cf29516dac659610b5e482c9b7efe96de96be6f521bc9953679e7db371de5bfecb',

            'centos:8'            => 'efb1098104c1e0905eb465947a95d469203b28e022ad5eb89ddca602845a873529dd69958badec43af6f63b22facf89bb0b59130609035a01dedd1a11f2cec06',
            'centos:aarch64:8'    => '3366cd870f02edd356e3cae36d073c4a82157f36a22fc6644e5b3e391a682f0f3a7cbc7cbcd0bfb523b9f00ab10619c6dc944b725ca4f825657a2807c45ab9cb',

            'centos:9'            => '8696cdb6dc247044926e485c7af518b773e019f1b58bd9e25c2a8646464215af435bd8e2f47bc7da0393eb4449d43b93df9a13efce3c07bc4363f2e4840e5064',
            'centos:aarch64:9'    => '49960a76af5580b6b43361d434ac989b04224b1f6d6fe30585f8707791c4a254ed9f2fdda24b18dc3ade7100f252abf845a70dbc6726d32cafb051f5df61d95a',
        },
        'openssl_1_1_1q'        => {
            'centos:7'            => '0b1183155b4ef1a9e9b6085f45fbc30f9acb71aa7fffaed37a56846a40fee58cc079bedfb5d229484747186311c21d3c6576402ea624dd5d9e464cf6eee8cd93',
            
            'centos:8'            => 'd3120d481d2bb46f403d7538bda5b3eadf1a36f1fa4f532b696857d73a8e930bcefd9844b8f44d180ab4af5182ee056914594ff919acfdca2af88a63fac19b74',
            'centos:aarch64:8'    => 'e77e08b1d80504c535bf1211041846e2784604e37157968ca198d74dab157ba02055c670fe65a07ee857c7dde4a8f7ee85e0fde9c8752d8067f389042a5101e3',

            'centos:9'            => 'c1f62a84df73071097a8ae9676510eefd07a9adc6d650c1f0899538c26ef0a4142e778e27924e095cccb44e980cdf1757c336ed86f557c8f84285fd01ccab30c',
            'centos:aarch64:9'    => '1f9c9eeee577a8a9f4194c57571d27570d7712e77a53e17a9a28ddcc51aae94d7dc84940cffaaa95b546358016fb3f6d0cd000a6fb3ad43353063acc77d2d27a',

            'debian:10'           => 'ed48f2cfcae3cf3fcef1918ace128511ec80067371fba4f7b8a582d61d067747e3297e2d356539bb5f41d4c8ecd31640b8a47cb5b2a926662995e70b3a2a4347',
            
            'debian:11'           => '8d850add822ecb0bd91345648f1589723db6c5e0da6c0f484df5b3227c27eed44221d55726583538ee2f85d7e6a2849e8846d7b557d687b2a224a309e0fcc9ff',
            'debian:aarch64:11'   => '8623045a357ee614a44b6ad3ea6ea1091936e6ad706fbda19b5fc63aa3e24694b0642d25d2114ee1e926deac841cc7a56d6192b6ded785de2edeeeaba1ffb48d',

            'debian:12' => 'fe3eb31dbd6abb4375ac7af31d152eed8e8223ef8fa1696910c3f9b6ef321ca5071d10fd46c59cd78c170e8f2381525b281ea136ca5f5d85254f66283d0566fb',
            'debian:aarch64:12' => '9f09bc2f252424189267546e16b682549523ceda22e26956cc505ffc8d2dedf9b2bb8fda8d022ab8df3127e80cfc2986af1474f3611a1fdd8114707d9ead0161',

            'ubuntu:16.04'        => 'f1a7b27bd18e8c4f0f73f1c15fbdc962286a352df6bc8b2370471ba4d131d8b1080aa0323f45b7caed6010f10e04c87bd3cbd9f716d26e8c3622469163e2f070',
            'ubuntu:18.04'        => '690a073071c6b6285fc667eb0af00a5cda825d9f13584d5195c8729b5ee4a7982516359d8a04291f3161a991ec4b4427a3f5bf15de6679a32cbbf0b9b5ccc71a',
            
            'ubuntu:20.04'        => '2caf54336ddb2913bfb6826f499fb7f2a03491b778c33eebc1c800adef51307135d64b004dd2148054ccfb04a44a378c1edfcade1c316b2dd19fd109851de5dd',
            'ubuntu:aarch64:20.04'=> 'a7b422ecb332f9562849c9be41b1591e60fb6aa16fcbf1298465898765e7ab969467a2c730e8df3ad1cb34d024ddc3d24b66127664fbff85c15cbb98a49d2db7',

            'ubuntu:22.04'        => '7fd643dac330512941e066c051ac45b90d468f07dc71966f588f815528bb542b5bd0bcdadef7cb9c8f52121909af9c26a3ea18280e95220f9d6d6574ded1a84c',
            'ubuntu:aarch64:22.04'=> 'f2869545a9fadb5bfb9dcdc3f834f93df0135c908b5e9b77ed5a964c709397a26b9a2d3570646578ca5b6aa35340c58ddf7cc717f786d39d91d268ccffe88985',
        }, 
        'cmake_3_23_4'          => {
            'centos:7'            => 'acd98ba5af2e41ed4cc8a48770495924fdadab0858a733b520c776a80ab399aba59986f63a1540fb05d34239da08bbcbbc3cfee5edf8c0711aa53915ba9ede9f',
            
            'centos:8'            => 'f33203e47aa325ca9de5944ef505401dcd034511085ed966abfc1acff7e27dd15984e557e37d60aa855a7108d3ad0a04dac9a480597c22eb2be87dd7de2873c3',
            'centos:aarch64:8'    => '8dc0d2abefdd59b0ecbf1de1aa57b06ad9e4315220a87f00af384a07757c527ba8f39e2be34533b8c406683730b6a53e507e61beb7eced7a908fa2d2f5538028',

            'centos:9'            => 'acb7b9804a82b440b6a6999e5953629999ed74578d297dfea3c6906d103415141af715e2733a53082bd47861a9e41df9e5b454adbb76596ef10b937e6e1558c2',
            'centos:aarch64:9'    => '4df98daaf2d0beaf81dfb31f1f9c1557bdea765b186b0f95576868b6dde3c15e0fcd54f3f39b425c0d379970a56ff503c01a00dddf99fe6707ff5fdcbc84049f',

            'debian:10'           => 'fd71bfb2805a0261c9ebf43865c9367c9f86508774c3e6c6101d1e1ac65ddd853b01ebabd47c22ea21d3053f902be8045137a937ed3562ada59f619db95d0ddc',
            
            'debian:11'           => '62670ec47a4216328ac7690bde3e6f64301dfd5f69ab0cbf576e85fc29c402ccf8ad79130f477221fa3f7148c85b48809cd10ff3af34e493198394a0250494d6',
            'debian:aarch64:11'   => '8a3598c6d48d29964aed64f36aec8224be17aec88e1fdc60c68a5c972d1dfb69c75dac5ea8592d24bbb3732c5b7979548deef35fcd2e0d9c087ef70ef3d87e5c',

            'debian:12' => '5296edf92028f34721064fc3aa4ceaf0ca733cf174990e0c8898b44eac1b4de2ac9901a2f807f588f53472d679a2940656fbefcc79a403c110d4374e1f5aa33f',
            'debian:aarch64:12' => '7f8ddc15da8b4d04772849de278bbee3165d2431202859977f4b14839b6c1dc7bfec9b956070c09fdb34e2678a77422e7395edd4bbc6a59f2dc032e0c5f2b6d8',

            'ubuntu:16.04'        => '5ca8ff2551ca7cd0ac09c937fde7588ddf5ff857d00fd5b4d9a9bec0953eea6755b45e6cd25a57e66773bc7990c7155785eb7259a08fd611917e12df7622e3ce',
            'ubuntu:18.04'        => '3762453aea3d3b3fc5b500612eb2f9ef5d959c238140e6f3f1a67167a21b5f6d0c848cafe0a71ec3fb501142040ac3683105c1e26713c6e5b728879765d924ea',
            
            'ubuntu:20.04'        => '4095376be2b2c3f59f3d5f50f5839ed6b7e7bb71f446f58046b14f709ff61988a93d2d43034df54936b53025e05bbe8bf3ab8131dfd55031ccc4c6fe8bd68d6e',
            'ubuntu:aarch64:20.04'=> '2345ae6977792e5f7b669dfc0f474ad7d054adc55ec2d76860599ff69cd17b2f372288150833aa57c03a92621edf35bc53a53a3b9efbd55367e3ec5c75619956',

            'ubuntu:22.04'        => '4ec12817cfd77e53a5dbaef0eab6a82ba4e478c0460a1e395a787a145d18794045eb1a2342794f82affc25ead8b8c4c1473294c15a4f3c8251c44abc9e2fc153',
            'ubuntu:aarch64:22.04'=> '7e7725a0580a41353d4ab9824b2e063b9f69723a90e5fe50aa1a340c1b72cbc43bf038a1358d2c3bada3e19e5dcbedc5eed38f6e22fb76be22162e05be21502d',
        },
        'boost_build_4_9_2'     => {
            'centos:7'            => '65f6d3d97f53aa25ab2534ee20df47dfd8eec4a672dd324d24249e5b1a484642cccde759b228d0cd13c0e3c733a651940c30e172fb3254f99fc98aefad5188f0',
            
            'centos:8'            => 'eadafc426d81b8ba49ea6b0b598a4dd859b80dcc68ed65b1db70bd6a0d08129730e2b67306ffacf232b9523ebddef3ee40775665cc285e96dbfe8e2db33a3d50',
            'centos:aarch64:8'    => '58ff1e9a9e4c4e2b6f50e48d438e867d38a48ff6b3978a5fc92016a0ad260ccf95790aa3010f37f235be02af635ab05f4926c439a57bba85ab1a03ceb586a8dc',

            'centos:9'            => 'ace3948340849f4a7a3ce8671e804016dc296ad9974a095281fd5ca293b2502e9a4c0f6f4de65e546ff34b2df2054be9ace5c19326bb8d14b8b6d8d2513a55df',
            'centos:aarch64:9'    => '6209bb562cf34ad65e23af215c9aab6c11501c5f66558934bba0fe75f528e8833f137df0aa62b0b739edec5efc0ec0858ed22249fb6965b5d49c1000ce67e0de',

            'debian:10'           => '67b86375f91fbb4fec61df73d2c1ede9ba2935b4a584e00c784cf9ce5f4869aecf0bf027422b6d99e8e30d84f2b292ae3d5302e2150fa5a35eec6a96589e22aa',
            
            'debian:11'           => 'f8e0f8f6d82c02fda0692da81ff84bc3bb11c7e38a913f0eb49db809734e52ada80f24edc59065843b1d3617470c1c59b53438c66dbb425c32f6022991ef9562', 
            'debian:aarch64:11'   => '428656685b880785ecc469324dc6507a65d6bbdeec55bd3b28d44a628654316af317ca78b888e18a2ba4fa8c366cafa80e1cc5a6152b310b6f9c95c8573b30e0',

            'debian:12' => 'e5c6853c7b29c0655a406bd34d6adc7d0614a04cc12cbda450174773607c163d2073c366099d4dfd386b8cbc7c8a6e9c90415414b56a7b6372c1004bdd15b5ca',
            'debian:aarch64:12' => '7bc97190a076501cfef0746ae434f3e16ed46219bd72efeaa0a5d183a571d4f76b7748287fa55d53ffcc29a4d9d4611235090db8284c927776e7f72b80f32ec1',

            'ubuntu:16.04'        => 'c606812ef72ae90107a2772a207aca042263cda80cf70d6793ad22142bba7226f275e37b9248aedd2e7723f2170695240383ead58faad6f76adefac059764f36',
            'ubuntu:18.04'        => '0abb7f49c044c0d2d187200b27942e80e31e06129f5b74d474d4927d1207feb0f889a0198cbd702a104939a48b07f8c070510d09f25c03f1d3eb5778b309a681',
            
            'ubuntu:20.04'        => '143e7c72498b496e1c67d2b547c6b1111cd3c574c0c0264228d870c17f1df85fdc1afdc7a19d5fb052cb3cb53304e03f46ccf4131cb184589568640c266b0bb9',
            'ubuntu:aarch64:20.04'=> '01a3142a53eb629b6a5998c1c8796fa9b8b654584fa087329d307267831f9d472e1b66e7aa0219fce1f2a67aee7fd13f9c644da2ea8d6f59e113f005ac7dae6f',

            'ubuntu:22.04'        => '9624954a8c8054334d3ed736b482b09cc4881209b91539c778650a101d3abbebe3888208d79061fba5bedae28b24ae1f1a429550df1e98988539679d90ff956e',
            'ubuntu:aarch64:22.04'=> '38737f09237a25d7185d1e603a293bb416b97f7312e0c47ffe7ee438cdf1bb630ca06133c183948667fc3c40346ab5239b92440762274b8529df7d79b2d659b8',
        },
        'icu_65_1'              => {
            'centos:7'            => '2fe334ebe9cd535e0ac4878f3111d2944544acae35a6135c49210fa1614dc21b2ef416434362e9e66d0cff0f805caa1850244f0683a9bb036c5b956544bc4914',
            
            'centos:8'            => '055629f72b39ff3b7b5ec01a4d140227055482888df0be455e3a861a86c81e0b5be9f9fbf379e1a2647bd4d042210036f9b505891ae7324f6696f811abeea35d',
            'centos:aarch64:8'    => '3cda6e78f7160462d620e09b8a9b56587735d5c8ce66ec4cf97d3b2025144871184d725321ca84bc2bd8dad4d89c8d87948ad0dc07930552d9611e55be258360',

            'centos:9'            => 'bed75601ee0fad9acfd11247dc5b7683335d2107e09a8e5968ee7fdafdc1ce41e5308a4f99ba3bcb3889215686d8348e131b19428f77a31b7991ca5fce2ff247',
            'centos:aarch64:9'    => '6193268cb31f398414fa5802243c24438553121b5ee0e155001689fe0ce2d579bf569c54b80095609361088bf9ba2307fa0b4e0ff80a5ffb8cd63e19d0581c71',

            'debian:10'           => '27c8d78336e0eb05b836a9dd48e276ee1be744bc9aec76c8df82755957cb61f3c06b3cb83da233c8b5fd48b3de287d5a33fd1bfb68b735b771bd7b13ff5085bf',
            'debian:11'           => '8e904a62a064799e38d8a01505abcf8ee80b4077f6b6073283a4e12d10e355a91dd8ff6ab6083a1d62684a16bf3557a9db3915c29189fb9e2448e5d7c639be2f', 
            'debian:aarch64:11'   => '3827029b4d1010acde344983c4a9823abeb0e2563284347723c84203ae9fee04909540bc61c03b401aa76d3194b6da76a7e4aa372ffc37c392abd231ae146625',

            'debian:12' => '859441a88f071757c4f68e1e3391d1fecb474035b9980539d4c87fd3be9e6ab128ea2ca98dd38fef8c948573c73884558917320ce9bb68c6aad7385166ffc5b2',
            'debian:aarch64:12' => '81761c82280e2b1627214edc3677b821632968d318c1dfa332a2e8ca8ca407de7364d60448751fb36f6d5e7ce9814016a9d801f5a372407e69e9dc8d0cff6ad3',

            'ubuntu:16.04'        => '6f90bd7077badd53abd9045572ef43c0590802e383397e8e6af238dedda00bf67b1fe5ffa48b66ddcd9d890761917c89c8e9dcb68db09521eb7d141324d0a9e7',
            'ubuntu:18.04'        => '32ab5e2c1a381319d00ac403994c8ab612e33b7517ae83737dbbda575f78a9ca6c963d2fdcfe753b5883df3b1bffea0fd357b7ce6f3cd4d5c9a0b4e03507ee7c',
            
            'ubuntu:20.04'        => '6308eb56bc5fad957e283db18f61eeeb01bac7946eae4282f885ebf200bc5c91865ddc83e203df85d0b193321b7735b327340ef3c51af176aaa8990ddbc11561',
            'ubuntu:aarch64:20.04'=> '382e8c59518153cd38aabcd72a3528736f141bc1efe077e655e1a724fbfc2fd21a9ac0c6408790bbd9e38e63755c39e9f5070c3b5da7661ba404c53e13c34abd',

            'ubuntu:22.04'        => 'b2b496de53b078e5a1c3beafb01170d24e5017a56388269709b93dc611094f07dd39033d84145079aec67234906670936aea79e217fa87ae532a7c5a4664711f',
            'ubuntu:aarch64:22.04'=> '0c52f6a38fbdd7fcb45bea0ab5aff7b913445a79a6b08af84b7ae657ba80573e75c110bc600ab96d5afe42595dd3e786b4dd12268e7ab8cef8214dbb2eeac0f6',
        },
        'boost_1_81_0'          => {
            'centos:7'            => '0ff852d4dc0960796a292211458f7dd129e2ad38cf8b4eac82be49485235f4c0c87d2fcc6c766b784cde9ab2a0af017303741cbdac8a7ac1d2b1749641fbf8df',
            
            'centos:8'            => 'a973378ca78e826624b06d8171688ca83edb91375ed933b500d0ab0387ccfd162b855012f6beda904614ed2524066b920020000dc0c3185042692ad406268b35',
            'centos:aarch64:8'    => 'a546ce236194c748d06ebd3b38195f01efe255490f8b791f633ddb9d2fbe67680e29d9a613b2640933efa0d299fef6b552b29c5e5ccfc888e647306fe3f934a7',

            'centos:9'            => '07abc84a115011534a2563f83104cb61a7a61663026111b5014d9b7708293c52884ce622ef2ed8adf1ec05363a9602d98cf995581f24a290aa8924e8211e79ce',
            'centos:aarch64:9'    => 'cdf0b63fee3b75a7e855b6ceef06c06a7157e05cf84882457f8944291211694b1dfdf2d78e795f488756a549aa2207b60b8255075bc95b0876bfd9189e42a7d6',

            'debian:10'           => '3f3049569648ef1ea4fbf532e0e01ac22231844085dd052261bb282c0e08321a938a0d95e5ca320ee833ac696d2978d894ce3e2180b9ea77112f89d797325745',
            
            'debian:11'           => '3f24be73f497c92ed38277a2d18fd914911aa37eb82e47b6a0dc6b7a6701de1a6aef0af78b2405788f81b7559712ba94db70b38d3601ac3d17ea7fb88747f5ec',
            'debian:aarch64:11'   => '77dd5e2127bda90935904f010c6568a9d59cb24d09cdc553e54cf4a2630a386d3c63a804b0a5564a4d1c5a2f66376b50cda6bf8c714f561e9ea78268342279aa',

            'debian:12' => '208b2e02f684a1d7c7e2e4cc7bb9699f28cafed2cc6913b3074738abefbe209720d74f0be7830bb7095315323c7468805efd03858dfbfc4509492de2dcc62282',
            'debian:aarch64:12' => '7ca54a31f0a5b0c66ead2ed38e3820b3ae5ada53ef1d8a35cb6e56ac2e3f5974be1df10ac6cc41174c380ecbaa7341dd0ee911f9f6299b35821a26214a3a27dc',

            'ubuntu:16.04'        => 'c479aca1c48e327d5a53b2696e23f29f564e5fee6eec47761988e36823c914e98562c03ecbb822e5029c0649d7e34749dded159c25238215b49d70b92637283f',
            'ubuntu:18.04'        => '71ae393a3592900cf1dc23dfb7ec9f14a4bbe4c958ef1fa2741b32cfd802a9b62854fbed4e86671e3b2cec07889bd74dc9cd6a39abc554ee2e10bfd0a519e40a',
            
            'ubuntu:20.04'        => 'c642b17f41ed7e092f2965fff1475f0219548993ec39fbb22b019c08f8edb68b3f876641ca825496950408e9f1851e3e078557a7274a48a45ed0770e005642d6',
            'ubuntu:aarch64:20.04'=> '48df0ccc8961f81140b146f9a1af7a550d903a3ba808f18f15fe3796380cf6cca576cc6552d040101f73494c55b29c64eae72465fd0a39ecb441fba4193fbacb',

            'ubuntu:22.04'        => 'ca620796d025b8ed860e00229887f3e7e985bb098d613a1ece4ac77b4643c62ad52f28eb6be702a4cdcdf4d7b3080492a43c424c0bc2e73c1195f0bb031fec08',
            'ubuntu:aarch64:22.04'=> '89fed9131b1ac03f287bb3475328a5321fbf20aec574e6bf5def87fb26921f5ed65f4c9e87ba786ccb4a725ef9e9047c9775e61155a72f64f91d65d08a838bee',
        },
        'capnproto_0_8_0'       => {
            'centos:7'            => '357c7b7bee86efe9ef1add35157202b72b6701c92ae035ff28e5d3a50705b1f4a6edc5d4903c65c1965173d044c21167559c3687ca4fae00b875aa261d452dc5',
            
            'centos:8'            => '20889ee963bf4d745e4349d5933c49dd989268e6c56cf2cf82bfec3b0f9c8cf1c5dbcfb3c82ee5181a919ba4ff398be9e8683398893e82f1a507665581092f0f',
            'centos:aarch64:8'    => 'bc596d867ce5242fe5b0c96059423ac7b64610ef26cc126d11cf6ee2840aeadfaa9b1d15a3237e7379dbe8d0668a2b9bf311363004f00b2bbe0d0a6d796f6ca5',

            'centos:9'            => '34fb43375e8b48755af734cb1d5fcef0a35c66149dc80ee01731459c03a38b192b52b415e34cc499b511f968d77dbf4cb4b621d9898366697c7e69c9e1f4eb4e',
            'centos:aarch64:9'    => '747d44e9a3630335840644068a2078d1d9491ea4e8c56bb81765e6a9a9767a84a8844d770b3a573ff19592ef70d1b3d24a4dcf87f9cc5622f8c7f704d9b5330e',

            'debian:10'           => 'acbd30dfc3f6317de1ad5183fc552ea0755e07c2fe60ecd33cd7461ce4d953491d1d3abe3370127d4009f2a69398d46a5d800e5caefc659c06742d55c15dbd83',
            
            'debian:11'           => '5ce7fa644ce0c80343eb13f109e2032dc3f5dca8da10c71d2f0c9f2bd47665df037618236b370b5448be48357902ea6860e2e3702f4953ef877f0a33b64e0af6', 
            'debian:aarch64:11'   => 'f33f9331bd2660a7ef9b924748c01eab43e400902e2f24d5766179a0e60d7be0e68091bbf3e08224aa8056b82aeef2f26afb750485f3ed805bf801f8f990c5df',

            'debian:12' => '78c7b400c5e62a66660dabe212b2d73b6ce845d18545b68dc90014960f960f2093a676e9857dfe654488c9798c2b30fd6f4c9ac9c2b4eeebad5fc0e75fd40f13',
            'debian:aarch64:12' => 'b233bcd7ce79aca3f4e6e6f50aee7d119fad6347b85f68820e5894ca2d0dae325c47815f1c416b5f17afe0d1cbc0b3885a4939857fd690506ad62a3b6db112b5',

            'ubuntu:16.04'        => 'b965ee209809319581369b96ddaaa1917fb0988325352ae3ec6b7078b8906f37e9c9319ff38d449ec4ed00c2c53d74f1cff02a566dc3cc2f68cd8cba97c409f8',
            'ubuntu:18.04'        => 'a86232387c6ac87190a52fa600c64381f89695cca274db995cf991d50909927c33a5851a623dd70ccbb055079a6579ad12219ecde06b3a5200ac48f60de1d12d',
            
            'ubuntu:20.04'        => 'dce98838b9ad8798e519a9c059d5938be635480c8d5d69b21cb0c7f6fc1b3be493db319f3f84775588ba516d940372d558d67cb7cca4200b0f4c50c63435cff2',
            'ubuntu:aarch64:20.04'=> '0dae37f9ec181540f24788b0bee40487c901d88373ca6912100b954129cb23e83d2600e2cfbf4ca357abe4dec1afc979f993e1d2528663a9954a0748e5d7b9b8',

            'ubuntu:22.04'        => 'e1778d55382491dc12e73df798aa66988be6177bb4c7421eab99710208e36221784453457077e308016ae7e6a8f7e2a82e38c1f8e16d140346b07ba4e614f021',
            'ubuntu:aarch64:22.04'=> 'e6dcbb3706e383d69ef4ecb1317ae9de618442ddf6a9ed1f14636dfb00f5a7ffe541253b0734b693446ac0886c9b478cf54e52a2b1f51d9761c3e5fcd82a1494',
        },
        'hiredis_0_14'          => {
            'centos:7'            => 'af7510adbcc09059968b1e2a6d46d149706c57777861bc296fbd733a4f1f4e3913431eba75d6ce2fedfcd555f8d3270e0fc0305cd039771b5832a6d8db23106e',
            
            'centos:8'            => 'ad80fd9c0ec9f7e66c4f1ef2304d27bee1b45472c43510f02530c188231d94541d1af09339bdf260b6ebee29822f8b6f5a6d45cf30c99a3897b85914e81fc178',
            'centos:aarch64:8'    => '7b70a8ddf8eebcc54a67bfe541ac70925274a8d1952d8b8fffdac9ea36b1a7800981e7c05d0cccf049535fce639bba74fb4a04237be8144c583f9a39d6368474',

            'centos:9'            => 'b270416b545a52a11334aebb4d65cbc372d313b5ab38ffc772c394470ea411b00cd13fdb0ef1363fd5c85a985f332f83f1ff9b877e00fbda4d2b7a4c3fc4b274',
            'centos:aarch64:9'    => '6f41894c895c303532d68a6ae6ba297375bd5b26cd0257233d106ba4f5538f24f9c0e2c88751c100660bf0e77553b853c92a61105082e016f121451692d2f814',

            'debian:10'           => '4c11a797f4bee2fc0abeac6ad0e03dab7ed8b1fde58bd9283b15182e2d5109adec980d898c683d5167b88560e141a49816e16109fd6bb5b76a5272b74a4569a1',
            
            'debian:11'           => '6ca40c0dbdd88ae728a2870cd1c9af6ec9bae553457e7579bf4d2e0e103be63a0c6b98741e2541cdaa2758a765a12c02ee390fcf147a6157d76f7488aa963b77',
            'debian:aarch64:11'   => '97488d306097b48beb57c4f054c6263f3b09d22aab38ddaf2370126e6d1dd53b35335c2406e999539023bf50c98cb4993c5e1676b8b16bad43974fea528d5f08',

            'debian:12' => 'a01670b858d63851947d60c01523a3d2b0365a8e24b8061193509559a6a078880f8c892ac81e8f69d198afabc2858c3bbedf177cd26606cb7a4f04d2a4d4bfa0',
            'debian:aarch64:12' => '579b57debdb04e003b912d03acfb19526ab923f0cc41d82232b51466ff9696b9b2bbe71340cdb81b1076a21f1ce8522cbe7f4ec6710307edb5ae419c2ca9af5e',

            'ubuntu:16.04'        => 'bb24f5453e47c6df91d158cfae948fe7763eff274b317bb545b8139159ae8b7ed865a075df7f7e7ae27139d247d448acfb04aef20f04b762bb643adcd3d36e53',
            'ubuntu:18.04'        => 'f4fa297699ac56d593075d680a8abf3c85aab6b19e347b7c4c2ef3ac17bdf61ab2d33c09c76a12427c28453493d7c6cbc1137ff99e770e9c88410f1b1fac52aa',
            
            'ubuntu:20.04'        => '9a1e135d7e73235a751a39df3861be202c47d4abb067e8c18e9a6072f9f2cc179684da6c783b8e65680639b34cd83972d6a8f4a88eee699f123cd84997cc38ec',
            'ubuntu:aarch64:20.04'=> '0e33fdaf50dfd0f0641b6791a02ae18537066c36a7af43e9329373f7ccdeacaa24d1ce228595899f746eea3fac6beb8f517364a2c401236ffc92957e5f6b108c',

            'ubuntu:22.04'        => '35ee4c2c28255454e3f42a8f6c00ba8ba803d66c5a73e3dfbda8a66ec99b96e8a4ea70125ba69ee50893eea1bd632a1644c0271cd11ab433d467243b2b290194',
            'ubuntu:aarch64:22.04'=> 'a7ddbd244e34ccb957af554420cc36f54a8d9f1304be1e3e8f8b72d89fc6c96f3fc8b2fda94447cb35a61a6bfa804c8eeb39b3f8b6d9cbc606df11f654eb4706',
        },
        'mongo_c_driver_1_23_0' => {
            'centos:7'            => 'f93ce5925d7e0f9992694ab40e9a30a5f2ab38a38c0500707a40ae77d3b9e4820cad9971b7e985de3253cb27b3d5761e0f7403aea8a445a88c22fa0e4a2eb707',
            
            'centos:8'            => 'd34c1c529ac5bbe9b22c398449272b0d019fa0cabd2d6e2b5a72f0c753d8910cdf2e3781e5e308c4ba2a144fa5fa7e1bc4a77e8f69d62aae3a54fdabe4c4644b',
            'centos:aarch64:8'    => '71130023dd05bfc424401175c2702aca0a713ece24b1d7027591b7985e048441553357338a229b9c44165fe1ec61498e695171c018d9d42f1490eb50b3be970a',

            'centos:9'            => 'efd8172ebf12f561acd098bd258fa798d8dc67eb4be25509184cc28700b0cf5cd6d6524f6d9896b505d252bae139cc71bf6687ab093b6a9cb48ea0339b5a5c1e',
            'centos:aarch64:9'    => 'e485677bce9c598980625b88f142d9e575b2aeb1c5660ba273fbfe5f7a57a635eb78dd13ab313191fea0578e44977771db4d32da8241d410fc8b6010e5b5eac8',

            'debian:10'           => '2b4f6812aa19735af5be0b8d1cea580564749c28cfccd18c8aa8184f3ed3d1e567f6d4e2ace765ef190bef28a7bca319ce1c3980f3e9b2e46eb6ec2d3d29b627',
            'debian:11'           => '68f25cec16382b3b872640572df74f74db4c01ef69f94542f46bca230eda5194665916158fe2ad7ad94c5b52f7d2ee92daca78b61f9ff9167e4646cf7bee3bd8', 
            'debian:aarch64:11'   => '1ee74e4532564c3f5bfd9caee6846bdc81878d01e78235378703c7360537da121e8b2a4a80bd2677f6dae7cbec732460d351932fb91259fd03dc536baf33b6fd',

            'debian:12' => '179fed21ff15552cb2f3a1d465f434742eda139977b344b8ad6ce98f52c8717286c8d51e97f17ca214b565dacfb845c194c6f1df80f019cd59165d9ec40c5f92',
            'debian:aarch64:12' => 'a1d0de72af66001c57f9cd77e45a1648f40f2e7ee8dd014f4c519125651c36f288296e3e4e68082bfdf8181c722d06a628a0b6771ecf0f7061f0a4cd7653e1f1',

            'ubuntu:16.04'        => '167d269e7dae1e93ecac671335d86a63a02e112c8d2bd52c02cd90bbeb6290aff646ef2583c8271516f4a60be1b9462096e73fd63956e11a2ad48416e9e4c5bf',
            'ubuntu:18.04'        => 'b7a9a4b231d95c5111b5d3908d4ae3f9729e619ef390c9e4bf3756857788ab1f24def12aaa93057c1327b2b9796b979ee1ad7be05f96f6464b18c1f6690ee02f',
            
            'ubuntu:20.04'        => 'edbc46b04d6baeb731aeec0ad54bb9becbc5a598733480f010a7e8f48c9088da338c4449fe94aba2fd86f34d5514005a5281f5e6e7b49bb63b55ab83f0dc631c',
            'ubuntu:aarch64:20.04'=> 'dda179fd669a6c117cd553826b70a662ca384075cde1fa1b7fd670f9af3bf762e300c44217583d1995c423969747255266e897f85134be2ebef992d4c55a8684',

            'ubuntu:22.04'        => 'f1844f8c3283a444cb186728389eadc66fbdaa13197c4a6adf8abe9d9962ea458c8acf4147df839bbce86e5e6f9b082e6128138723251189d77d8f238920cf7b',
            'ubuntu:aarch64:22.04'=> '5d3db587667941f9b77dfff83b4f839bb51aed47d2a927d93c36c5186c49112013bd93240924cfc48c4da60d196d50a6fb0c613622c2e09dd760aa63a356bbb2',
        },
        're2_2022_12_01'        => {
            'centos:7'            => 'e87055e3e686df904e70e05f135b1c2bda614d9d9ec55382569265e4499a0c0d49f82ed4f7d709abca8b2cced187679f7b9864ea4ec27d00623b8d03cd146fd7',
            
            'centos:8'            => '42c7ad8069ce4f3b63d3fa3f0d90024aee0760842d24038b11a75bfe4b7c05d619a8f304aba17f88d868427352cf756d6444c3bfb27ae61943cab38fcd4f0ec7',
            'centos:aarch64:8'    => 'e4f84a10a9313f6efdcf38e89aa8ee5be01ad3d51109793708485b4652ad0c725d9163973ca17e9f94d1e2c8c02005bb4fff733bd22c0ea44df6fcfa49df702e',

            'centos:9'            => '8a7f46c357d28ecb20bf19ec7a80a80d429ba9a21935d04439ab186ceb26f5dcd26f8e1301b9f94d187e63ba65393d7b9145cf6856edac3c344b6abfdf9e4b29',
            'centos:aarch64:9'    => '4322b76579386fda05d5c9150e9f4d58115d5b6b30dd5c64eae89e79fc538540c9e6bfed07973cd59c210f770f881a04875f580ec3d563df1dcedd97d4ee58c7',

            'debian:10'           => '05ce0c08bb5fe24fbadb64091315257bad52179571fc7670ac18c54e5ba98de2ecabd49d83da0d0561fc29276c9ac02fd98d0ec288b020533003034243358682',
            
            'debian:11'           => 'c81c8b897118cd591449321eb6ddd790b0d3ceb71d41468267f7d01feac77eb69e3529c9efe644bf49f960c546d0e18174a1840ff65b238e2321bc5db1acda9a',
            'debian:aarch64:11'   => '1836f8647f42898e9834ff9028714f1e6c3627bda1b2668dc3d832d7318e5e7294a7e1ec63b3e6a60b1bb0d9764d0e60ab807b647de634a240a2dd96a9114216',

            'debian:12' => '7d2a6cee2046a886c3f78b7772f73cbe017ee8eeefc4ae4b64ac7c0d78af326e42bc99158e915475926bcda21554d0ad41bf8a91a79e34ab328eed3300a84141',
            'debian:aarch64:12' => '6a3e92b5495a2d570cf62ee107adbc947d4cebd8cb706d162866f58092337d42a47cf4eeba5c78304440ccf467c327ea6b5cc06df015ec59143ff3d6247e1f36',

            'ubuntu:16.04'        => '0f97177ff035746815a379f2fec5128ed3913ff189eb2a728c170e5b82c044dd814c8d15b2cdeef2c4de96bd9fde88730a335ab925128a4faaa9da01f01c3b16',
            'ubuntu:18.04'        => 'bd4338286e807ac15df29c5e7c416a0a5c1ee5d1fc349bdca98e76b929fccdc13c63550904a47a971c3aded120a92f62c778cb07aea9674d368a50f4e80a9980',
            
            'ubuntu:20.04'        => 'ee9d3a1765db7d439b2c08e3c64ee3740964e5115198c5f400e272828d54551b2a28c956348508cb59890661287aa1d80461bb4df0329283ca077723b70f5fd4',
            'ubuntu:aarch64:20.04'=> '1a042a210dc5ff43f2c5ff82a947200d3a30ad1037143bf633660f7348d27a9786f1ca70101f930fe48063b41ffecb0a9f446a36520c932a096f837920b5b5a0',

            'ubuntu:22.04'        => 'a2153725fd06466d30ef483ed2f5f3b6303e53b21e2b1deedd2fe9848463d0487ae16fad0d3d292367a4bb28c69b5e43fe706e4d2cbf94c29eae256c36160503',
            'ubuntu:aarch64:22.04'=> 'd220e20079d345bf4f8e4b6e7136a7b1abd7e1a893983dccecfab056a738096ef565de60eace0968579ff4f94db77d5795f6641d4cc73d2260dbbbd325dfd5d8',
        },
        'abseil_2022_06_23'     => {
            'centos:7'            => '2831748eb46fcdd687dd092d2ab5b47a555f2b472463219f7ee8921ecc6b07550979011a594d46c0554c2da99f9cd8e599f1ee0e6370695d8fe9ecb23e662d70',
            
            'centos:8'            => '8853162fde7790712be1394660fa71ee2e4d8f0004fe4f3d7e08fab9deb9933fa25ac5fce8c7e119230415f4abf7c82ff896bddda1829dedd4e69868310cb907',
            'centos:aarch64:8'    => '2af0a1d05bb99ef63a367f06851ebc450bcb09118326e0d1e1592d67ce805cf2dc76571edaef0aeff8220cee9dac6584518fa3ab65d89db265124f86725a4c5e',

            'centos:9'            => '4cc7986da4a9ead5a1de6875b66d5de8ddcc082827f204e3d858a7e6ec97a1cbb59652f16b74083fc4e1879fda7019cc1ff711a191592c87e6cf4d77f4fb8ef8',
            'centos:aarch64:9'    => 'ab0fa808b6c0e1be76c6891fa8c3e68e3988684383ceea645a6c1902394eb96ff8db7c4cbc2e4a854f51fddd2b3e10e20775bb4720272eb24adfbcc74f06f173',

            'debian:10'           => '6f3568e19e6612a4b250e8ee0aadca04b45ce239b669b4d1abcd8d7613e9579df532877ec18396de5b7aa872610af0141ee358d4e4572d1fb6c71f18d6b4959e',
            
            'debian:11'           => 'a379bd91f97ac683f2e989473b77357630ac72b5e0eb00cd5c983d4c2aba653337ecd3f12c14ded3db667f14878364255e2159dc968963968328e1ff22669311',
            'debian:aarch64:11'   => '3d65ff346aa64a4476170f8b7c1cc6940da4c80aaa86c8f5e598af3d1bf1aa4f630db13518d9d557c23f613970b7b2ac6cd1e87d4f8f2dfd9f286cde120be8d7',

            'debian:12' => 'f1170c74f8fd0f0425e2fb63039280054aba0b493c36730ea4bddfd8ff5dbc12469281db1b9c3c7b5c9a215498976ff3f541424792d07b0108b3d9ff09bcfe60',
            'debian:aarch64:12' => 'cd33ce1b137ac6f9d6231cda9c180925564c8d6308df4c4dcb8c775432970bde04cf87c1bcc782eca98e7f85630ccdbcb4eacbdbf3494e7eaa3e7dc7139254fe',

            'ubuntu:16.04'        => '5a350d085eb3350d8b63fdb8734d8f7fbd608beedf006f5c7213725455f882e234668fca8fcb087e60afb0876187103631637b9424b28b06b8da9ce8cd05798f',
            'ubuntu:18.04'        => '1cb7251394f832a4c8e802c2c28e781d09065b2d42ce8ad284159bf82aa286cd219e67120c62008a14c0ea93a4ad2a9f0d67c78becf6f895965c5e92876d70b6',
            
            'ubuntu:20.04'        => '2f8124dac10d36f3a2c77ddab90f836b4ac92715626eb535bf735ad6a8c4fbe22b09387a06d415a73d1e2c2816f202d1cfce7b69f499169c55756832b3d4a3cd',
            'ubuntu:aarch64:20.04'=> '0de61392febb1be2abe396424608ba05205dce73677aae9acb514af20842a5c6a51c01496cf4a01373b3f3777679f290de7ba57a8120038f71ae6a37d302c1ff',

            'ubuntu:22.04'        => 'e3195b4912dc02affab881043d7e28fbffd5d235eac7c6c1b0e0e324609189b9c2b0f20ec172ee3eeed93894e2d143aed8fe1fc84358bc7668b11aa8ea679d0e',
            'ubuntu:aarch64:22.04'=> '15f1a6575b0ca2280a9fd1b9b520abefb2ed0934502b066c4b6cdfbaa96b6cbcf5426a8e8c7deaf5f2cd2033d851881adabc85fcec3b9cfb5b136071b94ddd28',
        },
        'zlib_1_2_13'           => {
            'centos:7'            => 'e3e477c30e0951c7039267414da5fcf089b4bfdb5d639a9bb8f891927dd4b374d1ce84ee987d788edee4bfb94ed6956efca3d02e1e0130c98a6130be6047af51',
            
            'centos:8'            => '5c69e0893e28dffda6d4cc1a3b8114a00505597891492610ab13bd37da940e6af20f4cb0b541a56f099cd0c1bb205105210ecd5fd20a37b971f90f8edaa207b6',
            'centos:aarch64:8'    => '986c66768a2ab4d5c6a5d1023c39c95a50f7f8030da63fd524a9b2612ad6d60409980f5ffaf7bf4542c18cda13678eace93104fd81ba18563904e03722f69ec0',

            'centos:9'            => '8a9613cb492acc53fa313f766c304d0d22ea163ea7b4244c979cb551dba63eb72902b133067b997f835dcf46258f3a3504984c1b1fe46e0c87a98434453807d7',
            'centos:aarch64:9'    => '2029e06e8509b1862e5d99ea37bde49fbbbaf459b77f3106e7476da066e297500df5902e2abcd2c147981f34450f016f1dd606d57871a09b732cada1bf6188e6',

            'debian:10'           => 'e9112414ab09958ef00acd6a7ae9cdea9fbae048a7f35a08c1e59dc83a75cd8f13e053e48945d245a955c1839fb6e4f2a85e24c8d8affd9a05275277d1b39ee3',
            
            'debian:11'           => 'e9d61ec7724358cb52afcf9fc24b2c3a820c47c3143086489374c5840b60b462c4bbf746b659bcfdcda33365cae0ebeecd89f3cc2c25a3464633d64bf46c762d',
            'debian:aarch64:11'   => '09b34bd1f03261553fd85c60d2164adb2dadbc3015e2a5467d1beea7d875720ca1ff7ed65f3ecc7fc35238f9627c2f479db553b9beb9bb41acf009389a889f9a',

            'debian:12' => '0b03cd27c9227729e1dbd7037834ef59100ac044a3dd2016338b2ea93a67d30bc62e1797360d1a5be8016510433b0fa30a603f139ee41f5cfe08f1d1e1dc0d94',
            'debian:aarch64:12' => '083e5bdbaa6de9e0b840906b0bd370e63e411a2a31f8c9e389d11c404c90b67d5f13c885ebe4fcdaabcc7e063d3251e1d904bbdb9f20455cb6dbf0c0cd03ef02',

            'ubuntu:16.04'        => 'adfc4d5c3cf53b420f61bbcd18c92e285854c79ea970c241a80909a15fb7bdbfceea5a913fe13fc777f48ec46b3a29edc0994db960f7b0f1a2b35ba3d387a2f9',
            'ubuntu:18.04'        => '918c9c913aa91ec017892868e99a4264f3868422942d42925fa67d51857e9ef157bce798798cffedc9ea65198c42eba46abaccb9543d2674a1c3bc46f0c6a234',
            
            'ubuntu:20.04'        => 'cabbb8b7127f8e1a1d78df16069127aae9c1889cadc8de2357b05fa12d168158858497a742efe9f647ace70d0666b275ffd55636f5cc8e99e7ab9a55c4563ae7',
            'ubuntu:aarch64:20.04'=> 'a09410fcb70c1e43888f4d533f33a469be35c9ac2651e0ab471390c009ea968f36bfb96e2cc6dbfa0dd9498b12537a5a7d71e79cbb894819a9f6a82a0ba04a19',

            'ubuntu:22.04'        => '3b88e0c0d959c4ea30c055b6e6277ce3075b794c9df7051f5be73923b26ad8b84aaec778be5fb14923d3f32a60fd72a9a15988df50e95fdb5244c895531ae1f4',
            'ubuntu:aarch64:22.04'=> '33ec80febf974a5a63b277dd8a382fd81addced46f2524ad0664ca14594282124d4de8e3e54daa8787feadfd3d18590d7a6915652313a14f6f70f23a816b00d1',
        },
        'cares_1_18_1'          => {
            'centos:7'            => 'fe1c4b256f406905893a83c16cc78ed41779c5c45e2831a7411717693b01afe04c7015be63d618dd7e7049ee1a5db5838f59c3c9fc7be9b07099eb8ac93536b1',
            
            'centos:8'            => '8c2e67d526979f0a661eeb04cd8718e31533bfcdc63a59a4f984fc7213b2cdd7130a6ce654063c3b3b71e8d408e3198fd58361014bf64c8e5cccae167b3fab70',
            'centos:aarch64:8'    => '22dbf5fef489fa2266652ba93beb25f2e7bc48f2de43c759e07b289fd9038dce099e4d4be243c98e1dbe8b7c0def91c444ec16c3c6fca953d382c1656040fcda',

            'centos:9'            => '257c7996ebae54e587f81ac3a8eb0f6468aecc47e928eb0d642d1be815494c7c5b80d45b402193f6065e7c37d29585a4b569bb5f20b63f160556a447da6e4275',
            'centos:aarch64:9'    => '889873b1f4442682556e7536876555f711dbb45deba4b820567552c6d3d0130dae297d193ac1a4c30367e93f88e1b2a2815c32e9edb04217535d6184787f32f4',

            'debian:10'           => 'dee0fd9eebd1c573843a5e7d1a4b3d51ec6952371ad4b5552697d8362e813bc1a0aaa4b8dcfd10035e2faba47ca915e04f74f1f5c13df2e1388ecddcec949862',
            
            'debian:11'           => '6cda179c5ab6df4ec20c31515ec8d5c61140d90c30f8c123e20390338d2db70bf574ed9002509454348d4d69b1c0cb58852b063c9e3e7fbf6661b20144b85d4b',
            'debian:aarch64:11'   => '0096606c7a9221e9a138a1e96197dab49ac892d861ce1bcb613c8c87a259171161996e768b706df801e056895d344b123a5d5c5ef760075ad6e127e810d6fa80',

            'debian:12' => '1bbb4a47884d8bee7be3ad7e53fe3465fe357e88ec825f8e1346d4a77e9f7a60825f48f3c37819e4cd76056664ee4bf8bd8bfc958fc3915d55daf50f4f962825',
            'debian:aarch64:12' => 'ad3ee98b12af250a606b678e6898665060b0e6037c5b9d5829f28512e0fdd9191ba4cc2ad2bc24078634504ec6b0762344d087a8773f325849760803d43e4cdb',

            'ubuntu:16.04'        => '695d8a170f654ae5bc85853f81230593d2ca7e3ce10885cb6994037770949499a84f5d396cc0f0f61b14fbd20a464fb8116a05c4a23bf77bc955e6d23361fc1e',
            'ubuntu:18.04'        => 'dd034742c890e08ff1bad5ae593c5f1976888ba3ebf15b0bad6941432b7e3c11bca474b990b12c6b47cbc2cd6e7eb6f3be37ea810d48f5d1e347d81ad72ef503',
            
            'ubuntu:20.04'        => '462d2b6414f130bf5965dc73f80e8ce4a4c26ad268f8b59e7b9b9012a95050a0fae5805fecf7ce432b5b11180adefad506dd080d707e5af57fe689adf363621d',
            'ubuntu:aarch64:20.04'=> '7136063ad0a3a7a402b3482bcd3bf2f78ac89436412389d2ce1a5c3d8aaecebfa338b84cd6db6ae2435718a107a2ae5aeb2e8a8db3d36598c113f5eb7705b34e',

            'ubuntu:22.04'        => 'e88789cbf45c0d3bc0e82a216d514534e209fca6cb35a7ffc74e8fb925752da550d459cca578ae4e1c287aab5c7fa1cb706b4b48b05449b761dd34998d9c3394',
            'ubuntu:aarch64:22.04'=> '7fd94e2fbd95f604d9f6aad9e07ebc17f23daadb2aed2f200da50e8e7032ec982ab37694486657d2a783c152fa85c7b586f1abc9b49b9ddcff5f14045e651fae',
        },
        'protobuf_21_12'        => {
            'centos:7'            => '85421b18c45c38e059201a8afa74760dbb4ca905b946a0938c2755863aedd1ae12ca66b065b7786e87331b0095f902ed3e4f0f3501b835d2e720063b04f218c2',
            
            'centos:8'            => 'e60db0ab444ada88fd574fe99f49bb0823f87d44f73676ea2c383208a9acb0c317ab1e049e4a1f2e77c2cfcc977bcf086b1c61be4401862b59a0ffc04ff5c514',
            'centos:aarch64:8'    => '06fa7819fa64ef3f838699e15b9fcc4dd1550fb1103adcec37197d8d660d384e2c1fe3b7a9eced4ea6c0d413384806e1fc6ba93885516c713b5905513025555c',

            'centos:9'            => 'a73a5b7924293af5fa8ab8fbcc974ebe5cfdc4828ba4ae56b995396837d7098dbd222b8008db0f0232113ef102f78d2374585b4e497628b2608895713098c3c3',
            'centos:aarch64:9'    => '35ac3434d17b4b9f9da1287699fd9397a1b5a4d1e68bc403ff2ef53591ef0bda1930e329b243c09c2cece2e9843fbb2a77c39d1ceac1c994915286005437fbe7',

            'debian:10'           => 'a1ccaa0501f38b132d6d53ae37115ac286b98b1b3b7ca13796b77825d728948f0b726aa7e788c3b43f8f684612594025dc04aceaf4964c244f880ef825643387',
            
            'debian:11'           => '3bc9bcbbc56f293a578a94e49bb6797de3529908ef393d6cb7ded9cfafb552ce08d117758f4e1924b7eaf84e6332a6bf8f70e68e4cdc4054ef8b0d30bf7dea68',
            'debian:aarch64:11'   => '0263d18f911e32581a06899d77f89f7497fa1070815e39e61b7c8364b6facc604f6f41be89c88a1592ff197176b3591870fef9f96c730653bb423c9615b7d5e0',

            'debian:12' => '7ef6a1040e7aef5842e9faf325b047fe3fd13b747636e900700d57d047accbfd806cfc68d872b8d03fc35df1f76c2995b10befa8ce0ce85957a5f9922d32183b',
            'debian:aarch64:12' => 'c98e7932d52d37cfb5a2c75ae0597541398a6414fc3d70181ff8992603229eb77146a1d204c9b50ec01ad17188877f6d2942eb0f72be5ab26b31ca5395baf55a',

            'ubuntu:16.04'        => '4528a95cbb836516ece10a6cd4232e49f30c9193f037c6893a07758a6762af1873661d51a8649624dc4c718388639189d77901b0c032bf13dc805d5f2e7493aa',
            'ubuntu:18.04'        => 'e3d22db5f890642177a7544f5ba4615ece40dc2cc7525871363f6c766e00e7812d4cd03a56688a651bf6ad3d7aab44d4b297cdaaf126d4d5d5daf8bda2ffade3',
            
            'ubuntu:20.04'        => 'a5699679bcdd7e8cbdfcf9d2080c3d2977e26eaf81a4c9b876b74523242129353572763e2271c6e5f334f66300043906bc32dccf5d2d5b26e79b4906f1d95e6c',
            'ubuntu:aarch64:20.04'=> '9ec093712c4d5890322dc0e134cbc14512b6394398a808e3a7a8648646fdddb624973c99273035f2959a71918354a444d3a9692247ddf05c2dc4c340a1c11f16',

            'ubuntu:22.04'        => '047829dec2d760f3f757e3bfd80873d99b0bdd79e0a9fa79f078f192005ca0dff07cd4cf36033678b401f7d4a256c1af77b7d7d9466afee4dbcfdec1151a3dd6',
            'ubuntu:aarch64:22.04'=> '71b64d760f35b8d9942ca0f8cd65a70e846b71a6541ced7b5a318f4f8d60bc6fe99b60bca9cfac83b603357065ea75ee88f8ec00d3d5c86120e757791b16b9ac',
        },
        'grpc_1_49_2'           => {
            'centos:7'            => '904cc8b7efb9788b7b645e234563c65a52c1604e4a6f505941da1f61dd7a93f8dee4697082c855731508c82117ff4569eeb846db54d22b984380d56752e77386',
            
            'centos:8'            => '84550c541a4dd9c52d7b4804df1976a2d17ebef841a75e527a6d42561a6421289ec814a8b18eb3775a07af11613fb290de632ce23757f634b07ac82db5540320',
            'centos:aarch64:8'    => '73b68790240a720141e482afadc26ce57c0e44b45b5324018af760fed7f0b1184b63f4cbecdb24acc4ce0562b9030b369a913349654793fc3615346563042666',

            'centos:9'            => 'd3494f579bef7cd179d3b2ddd9cdffcbec37373614fa66266db4e0b6867867aec4c24d86c16e600dcb58865483c5bb5fb3f7efd9e0c277aab7f5c74c17e1cf46',
            'centos:aarch64:9'    => '3a5eb19e320a8848548241dbac3dcd556d1e7dc45fbb91be3eca7c78f0421095eea0d78273377f08a137d8486d8d240906876e5734b7136db955a10d352cb8a4',

            'debian:10'           => '0db740d51582c69449e07d0ca5154fc4928f50d032949f75434abea9ae5f14e8b358c092e711214803659bb5fe411f14f7e0ac20e6eced6e6d3ada6a8b336c83',
            
            'debian:11'           => 'df4b6401382b87bc465e7520210f1c906098ad2310c30e2739d52d496609970e6eff63078c0a5c1e1a85c5359ef6d84d71197969a07782ad9bb2dd19548f3334',
            'debian:aarch64:11'   => '98af7146bba5431172be9750840f608139398bad4aec137f98f748b976abe61f7a1870af10db63d63a872b56085034b2a9c6a9eeb9c00fa03c739313f9d6dc0a',

            'debian:12' => '5a7bec683aa85062f515225b8dff93698dc39a83e660a39b57be08b834fe0324255aefacf9bf31e11dd9d6a44b4f880023797d5b0c4858263d1bdb367e73903f',
            'debian:aarch64:12' => '7e4f45891ab4a8e7b288b35f2a9f8ab9c36be09f1f7fd51e2e83656f86658d7f4373dcf2ef31ce1f4f535d3f35bc324e3372b431a6331a9bd4166d0c6b92ae03',

            'ubuntu:16.04'        => 'ed56546965e31a772816e1cecc5a3fe6b4e7ff6a6d648f9cbcb2a1facc562afd11016ff96127684dbbf17ab0f6305fbf41dea2a2275f8b5a0061b517fcef9efd',
            'ubuntu:18.04'        => '24e5da0cba4b522a445e91130f462220b847fa408f7bc96a14803d5e28bb0dc074e329ba5249bb49e06c348ea8ad7e4ae14316ba449203665e532176a1d4f477',
            
            'ubuntu:20.04'        => '75bfc10a7dfdf17db187cbf66b16efb200e7482a42833f6067b583110705e48d9cbfdb530e4666928f2cca1f874e9081ee61302ece9eec7ef79b5f67266f053e',
            'ubuntu:aarch64:20.04'=> '4f12e6c5c0e411592f8ebdda23a4ba698078cda8aec2a9c4e7625ceb5959448d50276a96191f945aa9359c723e4383516ed25c04eb51580c51471e1cb5b79ed6',

            'ubuntu:22.04'        => '1d4f0d440f5a8ffa0dffb4985dfed58138102859de6a52bdb552d4159903efce8d28984c4b6d995ead37f0cb2cc776f5a34d967413a808526ddb5dcb84f70ccd',
            'ubuntu:aarch64:22.04'=> '41fe69a136dcfc8b46defa4958afb55f62ffc3fdbc51ed75314c0ef6c81d5b5a6c826c25306493ebd78d7ca363361544434c531218cceef0d4d87379261253c3',
        },
        'elfutils_0_186'        => {
            'centos:7'            => 'ffda612e4b27156c52573e5e532e0b9303b3b341b85e8d26c954bc969523dc4da85b53f8583ae455492640ef27e64686a30d1318f542f2015c479e8b18ce23de',
            
            'centos:8'            => '52317c7b1bafe7e34518b02963f525d1c3343bf56d42a9b7ee6cc7bade69adc0041722a20b5f8ba63b97958feb5944b15f82b1fcd3515cca9392c5965688e644',
            'centos:aarch64:8'    => '35d44bbf469bd140e4099e1f746fa4e3c604860eb8ef057621f833943642f05a22b024a14225c091ed75f24ae29f9529c26d13283cd8e32bf11555f42921bdac',

            'centos:9'            => '4ff6eb779b9e93910081aae7549157691d61231f70de75281aa41e9527f4f31537ddf09e9ad09df44fc97b544f7155ece3121d8c09c867f11a18b0ec64c5580d',
            'centos:aarch64:9'    => 'dfa42ee571e053a29e0706c2ba6895507ad7fc31399217fb52592b6a2f5b62cb5a3acac278ba86602d02d286521e82268af8f53819e1fbc68bd9f0244b14b396',

            'debian:10'           => 'add68eb371dc43e5330c4c21dc9f6781ad5edcef0bb1c4869cda7eb37b56b0cb28fb8ff48346bd5b14853eaa5e319c149e66487f71b3aa1d95961eacc29c9744',
            
            'debian:11'           => '22c02ef2c002a7b63163238a2076800cac108fe8219bced478bfe0817d4c70ba7247ba76d0de2cac32b0d4196451069c63708909d59186df8f21fc2dc1702eb9',
            'debian:aarch64:11'   => '6ddddbff78b1b2d691b258d985c4231fa02a88872edb3ed9dec1e92802136b9736a0e071c43924f30dbfede32bd0fc44ce3f8e92e7fdfc5bebc810ecf48f13bd',

            'debian:12' => '0dbffa52eb3d6c232c62de65e2b74f4daaa1d1d82616e1b64e4a39b725bad8f4d912164d50bf2ee0455726ea96deb1594754c5b490582b1b9e27762c9a7d395e',
            'debian:aarch64:12' => '6451efc0aff1c21bea402b2423f2dcb64526c100cb4024e2fe40a49441bf5c8d35828982dbbf6c2e4315b7138f49aca99b7d45d4f1c06f79bfcde554c85ddbe3',

            'ubuntu:16.04'        => '16def13c740c6e04fe53839ad4564d1f2c12d1f04a88be5257c2dd177545377347495c2518bb49980d5539e06b32e4e69e4298dc5a1cf0425b62e9d2f41a6d41',
            'ubuntu:18.04'        => '330b2870f72724bead72aa4fc0c90412d3049253128e09af6de61cf162108ed10d6ac9d18736038904d3fb1e814841986c51c98b3208eaa9b2d9dab6b8ad4c07',
            
            'ubuntu:20.04'        => 'c5720ef7d3f5435e9fc72f5ffdec1580196946f70567aeb99f68536c7f0043a3b9d934c2e36d7d77f701202f7c6053a30fe8ec83715ecb2ddacb7ce1171467d8',
            'ubuntu:aarch64:20.04'=> 'ea40de9b17719d76567e8e2194cf7210a8cba256da96e86fd15d5e3019e08ee6789d2aca756175ff83e1230f61ac5b7af95abf6a3b951884b43501b5137aca99',

            'ubuntu:22.04'        => '2c4ae26635b7e8a65748f60abfd71793386acfcc9bf67ea95ee1f214d315fc243d1965313006cbf8c17214b52d84a31cd6ad64b302a539cd061d69b6e0db79aa',
            'ubuntu:aarch64:22.04'=> 'b70743510ccb7bc0e4f9ba9554cf5dd6655d09942b0259a9a94d042a87487fca43651651d55b3235e83bb55f1553b10381badf2f5d0bcd9ffa8a17ba781c7206',
        },
        'bpf_1_0_1'             => {
            'centos:7'            => '',
            
            'centos:8'            => 'f62b1a228543ca500508a810f21c216b27821c25d9fb031f5d82fb91ed33b2820c221fab253342da981457012ae39fe6b6c60bc66ddd6f35be3a7b6243ac7e7a',
            'centos:aarch64:8'    => 'cc85b21761a1a4a647014c18e1e3af0df958091fe688e5312fffc82ae066ee4f6ca9cc086d4b1e4f28edba27f76349ea1bc9a2196ca78ddf7486683929de335d',

            'centos:9'            => 'cd77074925ccb9f6b21a1dabccab7929ad7570c539ae36290c322424362b7a6cac72766b6818c2f3fd519d1883f0d72ddbec4844302b80cba1c732f35ae12441',
            'centos:aarch64:9'    => '9b3585e4ec90e310b3cf6ecc5bc87590e8351e76b9ff8fa385ce35097623724dd92f6d13fb485d44678f6fdca7e3d58b43c2360acb6036bb79a8ca3f44ef00d8',

            'debian:10'           => 'e15961bb10cffb49c595827e9302521a2381919ce5f023f7bbf413058f73f9c316c380b9bf448ac30fcf3cf87e78972676df9e9c2cba57ec102fdb1aefe99b12',

            'debian:11'           => '2b9555bc2c18fb6b6d449c0f0fe8f835b54099d526b4a6c7e1581f201a51bfab02f68ac82c764168f8fa2313896abbb6fd50a756ab162bb6f47ec4f5c6252828',
            'debian:aarch64:11'   => 'f401083c59ef906c29bb8418ea307802547a82e73f59a62af1ddeeadcc5f6a03bbbc80ee5286b62681395d44c385d223a385ed59aa5f9068e423979331d02a32',

            'debian:12' => '4b6b07476dc3c3204651f28dd30abcbc07333e0accc5b47b0e92f5a3f26a3ba5725b5dc8cd54c08209d8f72a73013344f3e9960b9eccc826b59d8290fa5bf0a2',
            'debian:aarch64:12' => 'c40406ce431a1e084644d0077890c0e2fd222d071207441c64279513b0d1862a40760a2ed396fb633eb4d54b5c9f4c167df50cf4213e462f1c52723e174bbb34',

            'ubuntu:16.04'        => 'a3e098dff32dbe9563ec5aa221862d44a282665e1f2fc19419ad6e5fe3ae512624956b792a8379378030501cc04854e26127ea998118a8c75d10181ea430cc1c',
            'ubuntu:18.04'        => 'c4ba6c0d083830b66473aefaeab8b9ba6af7f8464635d6f5ff342354e5a80937e37b09f5e02c4eeb092e0d1559607c489fe38d4e3ef75f0efe049f4d3aae39e4',
            
            'ubuntu:20.04'        => 'a50e852466f404a3b8457d8a12e543205f84c0d2bbd3739aa4b5219e68914e828b7cedd428e37e65674693287b8868002f3d3c3ebdf6debec552f2b3c627adae',
            'ubuntu:aarch64:20.04'=> '98ad7b4431c37e18f47b5bec8d5280d31d8fc4ed68540804d069149883d1cfa783d0d7a5798df5db2ccf8b0dfebef47082b20efba6c076af499a153f96a77530',

            'ubuntu:22.04'        => 'ce51ed56b8c754adb72c2708ff067f94f03b202866c23c2634b6e47b62a21deee223baab7ef3fad11f9da3f2649784de65529ebbdc36367c4d6c76d91bf4d159',
            'ubuntu:aarch64:22.04'=> '0a36a4ba932998721ea90c2bde924a3c648d4b57e990be4436a53ce01e09f56e87df3cfbf10a1249f885e1544b463a23c839e2a2d709fa53ee70f1adea463f27',
        },
        'rdkafka_1_7_0'           => {
            'centos:7'            => '',
            
            'centos:8'            => '8d220662ce00e82184aa58e40a6cc7ba29a49682b8eb90e50168098b9d749f006a934aa8b18449b2b8e3cb517b74bda58ff185bda9bca766063e74aa1d0f423b',
            'centos:aarch64:8'    => '15a45dd66a703e347522953098dec6c231e3e280d2ee14e614a34b37699ca914a54c7252443317915246eafd926effb75fcb38b7a130b1173630fc1689fec30e',

            'centos:9'            => '2c642a289938597182dd040e2dc47e0d9c69db54c056874e941fdb681145a30a7904bab0db9403bfc068c753ceac7250ca5fef7c77ecee9684a47c032a340997',
            'centos:aarch64:9'    => 'f5029e6033735474244bb6557d0c865a62eab3f983562f2a04b53faa13a1f1c98ab21b397b23c21dbafeb4bc1ff41ab1fd2872c6bfe62c5887789be70fdbbcc3',

            'debian:10'           => 'b5b792a674e0353897e4b4a3432b54d05ab95722370b3384131cc7f853ca29b636ba61f5035a4bd81dc8ffd58f1023c784ddd056ee021f4b49ded3e9db823c72',
            
            'debian:11'           => '55062b546aa36ff8db51750d1ba7f27bec170f804fae4ce2426d0e24040af507217e5ce950d314dc1c73be5d33bf3a5acb8eae09626d86e59fa686ea44630396', 
            'debian:aarch64:11'   => 'e28a06e6cea4cbdbcc84d13e78dc6723877f92e18d8d7c654c9d7660421d0e2cc27e45c6376a2f4c20945e4eddcb210e773b107aa68d9602694741242d1523e1',

            'debian:12' => '08c5031c08da4e2e6a630c476051d245661af03a51c3635bac3f35adb1ba7a7263f7ef22a53aabd6e52f14bb6d48b9f158f3f59acf69b26d31af832191919831',
            'debian:aarch64:12' => '381be9aae92638d35affe627b81a5992ad7fc7a8bcb0fa5a01ebefe87f9a310ba16b282802617db62503c5ecdcbfdafc60fd3facba859bb8cb4a52deea62e6b6',

            'ubuntu:16.04'        => 'f55ff7286c70c250d147992def07a1c3a9cf2028cab784f6ed4abf01f6062ff16b7bf783a2454a9fa04bf878b2e3ae74150cb51086f36d8b41b219ad03b2872d',
            'ubuntu:18.04'        => '533b11bdb0cae2c06ab6e76eec90982ac442bca58c7c73acf18cd258132c293c615c81026ad99f3fd3262e5f0960e533e4962b58f91de4cbda5c87704734c510',
            
            'ubuntu:20.04'        => 'c713a9b1e9921105636e5b3077d8d2276a5f01b11b764ac356ae3101ce5122f5de0ee4d22151011927b921ce0f4eef6c61215ac1c1266e7655a8fe33ed5b6be7',
            'ubuntu:aarch64:20.04'=> '24a3f1955ddf6abbdce55a977d7f654b20c124f01f3d491c34f6d06219a443c02d1b15e6e85c9564e516bd72194732cd306584064adf19addfd4370760962fe0',

            'ubuntu:22.04'        => '4fb3f9c2904f847bd7e95ff1d7d28c8d6651d85e92b77ab9376de547bd87e5e8016ae69907d54e5c147e244abb48c8f47ea96eae3a992a0c57111393ef2759cd',
            'ubuntu:aarch64:22.04'=> '32ef466242834bc2eb72e439121353cb240fce56b8dbe90ddbf98673a2b752615bca60a270e5e5a2c0ef7bb531a2c5209f2d61428047c8d777a029c6bee5ac83',
        },
        'clickhouse_2_3_0' => {
            'centos:7'             => '',
            'centos:8'             => 'c4617eb30ebbf4b36c2c1e8f0bcb06b93af18b10cc1d31e42bb968a519a4c9b2b8e0ceff3c942437efb6217d7fa0827bac485233f8199dff4dd4f3b22219b4b4',
            'centos:aarch64:8'     => 'b37b6b0e7d8e8a880f6ecfe3a66f2ea5bb31c28d8c3ed1512f8787a6582cff48afbdfa776f02323e69912852292d1f100b4b4788b7b3ecc9e7514336b1daf260',
            'centos:9'             => '6190e9b563196e9c1de397af376a28aaf3610490a53b0dd4a86a4e6469a828420dfa956d1577c43220c87cc9a1f86207ed9d443ae1dfd99a682d156532027dd0',
            'centos:aarch64:9'     => '24b8e56a61a7726d9d9ea454d6c63a29d97d1f052976fd5041b1afcbc8de7e8637b9373380b380304401adf003131c0be36b707071351dc89ccb613b0f145f8d',
            'debian:10'            => 'e55573710760abdf19c83c5a102270a9123ab233803f66c4bf7d07627113b15cf56088b680e54c1148a2f08ea3591f77dfce53a40a6885cb41a7f5ec1ccc3a7d',
            'debian:11'            => '',
            'debian:aarch64:11'    => '43b31be1cb13ee3bd4874be08575e23aea71b77d562dbb684d152f078741fb5a63196e1e12d80fb9f6de7fef65be4d03844e72ac26fac855a9708ca2f58fa805',
            'debian:12'            => '630f5f735b18617435c48330e9ba0c7931de58fc6bc940a0c8db82352bbb27a046789779ff6b488d32c550050b2a1307a6fba4eb1d08123acd1a6c0559216613',
            'debian:aarch64:12'    => '5a47c0b89609b522b41915054cb1bf04474f78f89915517add9d20efec0a1a07c468ba7004d5816df489d22f5eb0cc2e6120109f77284eb7aa6f256d37cfb7f3',
            'ubuntu:16.04'         => 'b5af6b9a1ee7e8d0594c506b83edb62d0bc6a42ddc309286d11c62c42d2e1f0861f68b9cc2112989f3cd34513ceb512c484bf0cf7eb2125cb70c9e049ab23f91',
            'ubuntu:18.04'         => 'dc90da9e3ea724073d263b7282602c278144d0dff3727ce2563baaa89361cf2391e18c4fbf1f43f4288baafe47a1cd6fde561535743f3534fde0d2707e80ff9b',
            'ubuntu:20.04'         => '64e04f218bd559a7316b2fb29c9adf24f280452c15169d892022ab9ed35d3e875548a3c5b0414eb9986935886b830055fa8e0516864e636a5f988af76d448877',
            'ubuntu:aarch64:20.04' => 'b268de4c3f01fbb7d5aa1eee9a4ce6b68284319f0e35a4bca3d9078463edb548f2f71b71f8a52eeddfc0c0b91910778e09e9429aca713e8c1d7f8dfe5f763d38',
            'ubuntu:22.04'         => 'cdcdcc6058cdce287cdc5a269d45b9dc4eab08709ce5bcdf714d9c5521ef60eaabc87e2bbae6b008c4a368b304aea0597bb02ecf4abf25e84b17a5b353f5d5b7',  
            'ubuntu:aarch64:22.04' => '2ddd73a3274170557716356a19d9583257da0ccaf98fd2f7b4d11c14e5e2f45952320a1d20f0eb2f8e7711c28d28e636085a4cd53ea1493ef11c707dccb72021'
        },
        'cppkafka_0_3_1'          => {
            'centos:7'            => '',
            
            'centos:8'            => '17f45f9933af2f646fd678939ce8c2c4d9f1cf601802747fa58aace17b7ad3184f07acb95ee610e3eb5c7db80ab0be1969ac13d1db44a782b92a3719d561b372',
            'centos:aarch64:8'    => '0386767cd8a66ce0c3e08d1e9abbc5c9e4fcf7fafbf3b25616b078deeff2a0ed6765a2741d08acd24229bdaa45592e949e2b973f7e08eb861c9561f0dd51d9f6',

            'centos:9'            => '16bf1a17efa87cf4f6979655fc1701b695ac09883916a48c699b1c7664d97ae86bb695678eb861cc90c14c24acfba92f09d5a0e69c8610f796ebb8985e5278dd',
            'centos:aarch64:9'    => 'ba61cb0c3908ca3d3298e17c6aa1bbc15d64ec079377b710b0c4ca26679826ef6fae5fba20a91c8d92a967762c17149b3f42c7882380fe439c5ab75ba79b9cfb',

            'debian:10'           => 'a9dcb4985b9d880e6a1857aa5050a023d4aff50d1d5f113d3f7961f85ba3bd3840f9e4f561c16df0a84eb2a730772489595f862a4778546807bc890d1e36ea60',
            
            'debian:11'           => '42353192bea405bdde76bebdbc3631240079d63839fef45dde360ab0e5cc140c9fa495c1bd25a08a6baeea4ef2852fbfdf9a390b56d7aaa97ee3dcfd11f9f6c4',
            'debian:aarch64:11'   => '6b7bf6bd43aa9e9bcdc3010b82b73aa759f8345a7dee8dbfd675fbc6b333cc823cbb308a3de8dd825030f6a6bc82560da4383d01fe52a3037ec3cffc10bdf37e',

            'debian:12' => '9eb9df0cdaa8dca8820124b5d54683d986082a59ca2cbcde4861e18232f6a67b82ffa33d2d7b218fd287090d3e2531c4ec483936b528eadec6804197b36066f9',
            'debian:aarch64:12' => '3b62ee7c1c174249c900af51100412c3d785693cff25ba444844a99bce18a381f12b5ff7e61270e1bf6bd3d11be98b6def681860b5e8e7eb1702d5f4b37e682f',

            'ubuntu:16.04'        => '07c2f1d1abe9db1be55db52539829acd1e3de7c73219a02c15cbb53035eff28b017187c2bc7450bd44c1686a1a58ffcbad9e2e268dbbecc78a66dab6b3bef960',
            'ubuntu:18.04'        => 'cd8aec15750ff2543924cb218ad0776a46e7b91308144535523196a521f186bdbd4c17f93f5f9fcf7301aad9cd5687a13c019fe2cbb5cd129b48b0ea9124506c',
            
            'ubuntu:20.04'        => '12254a9a4e8905308333659155a53e0aca3af32a841d8a57e643613a970b2d6ad3994d9ea113e2b09b989ecf8073dc06fd71a6e58d376930ccdb876aaa0605a0',
            'ubuntu:aarch64:20.04'=> 'cafea8353f583a831f3ed3cc0ac3223df4d8fa9fdce3a55ba9369237caaa57cd7529af89a504e09e63e02e5e577d1b009aa4af546379916503f1c3c4aa0d0df1',

            'ubuntu:22.04'        => 'c0008d61a0fc35f115b4e304598a255c0abf55e5c3827c4d8b20f1c4c29545e71a35573f57f6d339b9758b16ebb96ef26147349d6bcdeb7687b469b8cfeb5d33',
            'ubuntu:aarch64:22.04'=> 'bdb6dee120d9c38c616fcf05ee7c68566283ce98ea197911a44eabb63a8004e8d029b50db9afe8e6fef885dd50120e2b5bf61b8e0bdad5e5ca0f26072d32a56b',
        },
        'gobgp_3_12_0'          => {
            'centos:7'            => '',
            
            'centos:8'            => '2b5491b26eb3bccedc362d96475cae366d0479a0165a1f80726f33b56144beb2fb119b235a466b1a1ce8f784fa0aa7a5a7861e4cff719fad735ac5a7c42a4e76',
            'centos:aarch64:8'    => 'b9676d7893a78f7a5fc5c93f4d92144f89e7ef6123d7043e03c8fef573f39eefc35e69826115c13616502c10d5839ceb369e82a32165c008e5d4bdb91d791b89',

            'centos:9'            => 'cc1eb3c842cb46709c61f1059fe1c8335bfd7f7ac95d5a050be0d5ad295bad4a664001ac4e44a7fd694445decd2020bca0a976dc807bded39586a12d3c829be7',
            'centos:aarch64:9'    => '63e603d48628c165e74257c1bc8c3de4409fae683dd3ac5965577285cc772fdec4203c1a9c8a1b27206b1b9ac7288e0032ca8ecc72eeca40b2bf036b6f50614a',

            'debian:10'           => 'e0ec83e7fd8362474917ba1563ba3aeb3ccd01097f88a0f1032b57c1929f30b886accf448fb06fb54554523d1764c16a09d0db8156d2edfa7b15b533d19418e4',

            'debian:11'           => 'd754c303f8276c29671bfac545c8e475ff6e0d4a0e75f9b6af04ab5c61a75b823433101b2b1dfe7fed9d7ef46fb8a5ada70bfb1b4a9bb6849966bb56021f002b',
            'debian:aarch64:11'   => 'd32a796f4e6c42cd9faed42c8736ce0cbc1b6a29a1bbf1cd440289439a2088dbb6c54483b178e9a983231b1e2a672e5b4cfd1c3b11a770f31043fd8ce24a0dee',

            'debian:12' => 'e82b5e58cd994fdf8c1dd6df69349cfce07545ef52635c154d0bc355b72f9e75396144dbee7f319ad4cbd165eea3657d868bdf16e7d265e0e370a1795a830b4c',
            'debian:aarch64:12' => 'ebdc6bc681c00fc53182aa44c843753cf20252699f73e45b927e4a58eedc1600fe0c9b11f09ebbf25636657f8174a33b1030e91173aee2c14edee73323af0622',

            'ubuntu:16.04'        => '45e72b36e3388e3889efadf3beda8c533b363d9c85f835b9374a416e3479d8a882e0c6ea3e7f395f65acc4d5b5ac0696573bc054c9f31fa2279fc2f849cfa479',
            'ubuntu:18.04'        => 'da1b380cb572fabdb203c05a62a36637c73c8d7c8deaa529fd5c04c98a4bef965f2ebceae26901e7490bf4bb65011768c6034f9d0b35aa1fb40ac953a640f10d',
            
            'ubuntu:20.04'        => '43123522322541993f10097dc142d2e457d272e57b631b1dba1bb254772536f4531c4b55f978f1196329e592e821b7c70371bf3694419d35df7225a508f15db6',
            'ubuntu:aarch64:20.04'=> '4c93fe16227ef6ae8cdc945a4033d94ffafa4df7986a97390c261181d4f78b1ad4b6e3b2e0336645d7f5c8cfaeda5ccb3683260dc976b763db0d3d271f3125ce',

            'ubuntu:22.04'        => '9583f08c9927ef60ec6aacb76efaa5a9b1e583a9765697cbaeafce118ac1b56aaa7c28afad1caf081c647fa6965d0cb01f27d5f9992140cccdb019ac0d866002',
            'ubuntu:aarch64:22.04'=> 'a5b0e9d111c138b0b0faae997186a3d89dea9d1ec770f7cbfcd2363d2d66e7d44a19def6a5b966a0dc07b28a166d97354db1cea25d9fc68f7ea158e5fe16930a',
        },
        # It's actually 1_1_4rc3 but we use only minor and major numbers
        'log4cpp_1_1_4'         => {
            'centos:7'            => '',
            
            'centos:8'            => '065216ab672b3dc4e220c6991ccf9c4af6ec8386c6fe22363e3539b75e00c34baf9ff3f7116a485308ac38856dad20be0daabd28e8ff3f484fb71665e2a193f1',
            'centos:aarch64:8'    => '1456068273f0ce7061f445e085f33426b17371e83a5820dcfb0122bbf2fe99fb0ba881add5d76da910a849349ea933e0533dd97e66824509bbb43c027d59466f',

            'centos:9'            => '599724bf68d52b9873f47f2f8d0e776e5c62ac8e09ef29fd4903878dd4aa15afe51178e17c1ffac7f03f18d7494d107cc93432b312882fcbc5c3e82077141e6b',
            'centos:aarch64:9'    => 'b987fb74fd7af62f8687398c5ea7d58bc2e3dc5e17f9073834e59706e9f1908ecc800e0b8f207a81a34778f90be15b5976c44bf553f182b4819a8ee82a0e067a',

            'debian:10'           => '670c64c7c52388162e699ef974704d031a9f3b73e2260037ec8107cdcd00cea9b6179f840fccaa287c5b1770ffe3464f9545b76e76794c349b5b3b83a4c981d1',
            
            'debian:11'           => '0dd3ecf33ccdf4f069cffafdd35f496ff4965593e4bfda711f00b853f6071f97173e6f36f255b1d409eab6f086d328c7d93442ae8d037a9e760720e2c78fc516',
            'debian:aarch64:11'   => '3fde44223c5876f3623dd2789e1b1e29e56a64a479d433fc3029d5abda8441d24a11b6841661b4ff0f7ee6af9047d94f645d2477017a4d2341cf00d41e877e47',

            'debian:12' => '15054eeff465a04bb911c109d32ed45f24584603643780562cfa0eab47db563d1d9f94174efdd09131d67d10c07e72ebf8db49487a39c807e734796e90cef22f',
            'debian:aarch64:12' => '919e2932526b79dc8e539187b4dfd84c7c0e63c57f1c454d839fc2b13ba0e26717eb5677c30581f717e9ac20e03895fb2acb752b79756f2d6136a163ce50f9d5',

            'ubuntu:16.04'        => '1e8d24dcfbe1e867971a1fd73f567b0a28377edba341b755652b1ff08601b004e0b3fd6e29d8d0b5045befed602c2552319e65388f952663fdc7b1ac52935029',
            'ubuntu:18.04'        => '9a6607f6defdf519431e5898a12e03bf58786c2ad38365d3264812082852805c6161531d8e16d4f77a66ddc14f3b98c6224c757355a5e8a030ce9e6279506db6',
            
            'ubuntu:20.04'        => '3b3a53fddcc959cbd0387265099c148f7edb4dddc64140073d995566526720f08486251025ffa416110cbc9a3014df1e0df63aa253c32f3ee97b729a4b3e1381',
            'ubuntu:aarch64:20.04'=> '3aeb58b2cd1304de2dc5d26676ba6e12e6d7dd37d9b22eb4f57cd212121f28f601ce4f645ae41bd1f999a793c2ea9495b18dd0a223ba33e19c67bc61ef78665c',

            'ubuntu:22.04'        => '57a8d9a9c31ce4d69a3a510733642b09cf85c3a65e45255f33673594c606777e32efb954b186f27bf785c24f48fe902925e4517945889ac1e3b26144a4824ceb',
            'ubuntu:aarch64:22.04'=> 'b377abb67ee57156926dbd741a3f9e6ac3578f93e3392ec89156b70162f0d904b49931957deab87dfbfc38a7c268edb5d7dcb505a3fd3bcb6a4b80dd50062246',
        },
        'gtest_1_13_0' => {
            'debian:10'           => 'aec32e10b13a6da79022f4535c0f4aa5fbbb24be9a6caad6fba8e1dec27a6264bc46d96a52f181519b0257d5d1daf00abee38d0d339a31dd65526db63c0f42c0',
            
            'debian:11'           => '7f64793dac5db1fe17ee8d5fcd40a826b43c9866a8ace96143eec1a5caa367e815c40efac431c132911248ca660f3a5a0d3cb6cba0ff5904949b10c8412aa110',
            'debian:aarch64:11'   => '2a7c9350675694a760e608dda1beb453a7c573fe66384764b78079d1920be290d09cf159c190db307f278c4aa98418a1b81c3e00ebdfe8ce3550cb375efebc6f',

            'debian:12' => '518654440ccaf4a1aa4cea365a9382b61627447627db6a4148d2ad4f2a0696e9d533ee9666b58cffc2708c21ffb67c4d6a0cae49203ff4bd1938eb50334c0cc2',
            'debian:aarch64:12' => '37c5f3a07d2e65b7a1e4e7715c36648e5dc1028a7f0f3b3734a6ce00104fd97420f5be6bf2fdd6c114c0060a85fc6cad6f094c793c5a3e1a24fe93b5f2ab1b04',

            'ubuntu:16.04'        => '2cfe621c3d4b6f737626bc700fbaa227fac43001ea994874ecb9a8d6203944489561dc18dea5ac46af56537863d260742f1fb37e43672c1451a9465686513219',
            'ubuntu:18.04'        => 'a07cdd25b47402bc0be4469ae9ec6458957054ab5c67638019314134848739f6b7c0826dfa2b60d9388609298e5627c0f8ccddfaf46a3623802b304ee2754e8f',

            'ubuntu:20.04'        => '32deb81da67f687c2690a07a32056872d371c6eeec25f20b8d27c2c48d779d35c820de91b64bc84a7d0680cc4110a4e690f807cdd28bfe74813f97ddaa970d23',
            'ubuntu:aarch64:20.04'=> '48c18ba74b230165faef391b97c57e3cdc37dfd8ebef780af0484d192de32ed4e4cb363985016cb0b9d5c7f150b3bf3daa4f5ae84da2e99e206f8456afb5dd3e',

            'ubuntu:22.04'        => 'eea217dedd561ebf45880802eae6ec29f1648ee8e039434a0e98149cced6072f1420674b4e13b66be47ddf6b542db32422266381669656b30792b5549f90afc6',
            'ubuntu:aarch64:22.04'=> 'eca67a378aeee2521954b6bfe5a6f1c2e5003013232e4e015ac89dfbb1b9047aa41e1e025cd217f5d4c3764ef9fffe2d2d4bd0f663a2d69c08ef16d8dc6e8b9d',

            'centos:7'            => '',

            'centos:8'            => '8144ec86b53e611fe1efc6ad6d128b5ceb8e094b8d6f0a7cec17d842015ff5059b1223d3b7a78e3d70d936590e301c86692894d923f6c9e9a8602f8e51caa6c7',
            'centos:aarch64:8'    => '4e11cd071c2d4a779645c10058bbdfb1d1b6c9fa7dc2ab9de0cc0f06452d074f468dd72ee0748e1868a2570d5eb29a00bd9740aaee379eb4fc75837dd43ce857',

            'centos:9'            => 'be09e658acd762e136d285a3308d30f2d35818a5a1a2d78e543141b6c957d652301a9689584669031ee84ba7f7328a59f6024abecee85dcc5b70fd37e980c720',
            'centos:aarch64:9'    => '97823fa105bdab03372f0533db18698d02aa63289c9bb3267d77325c1ba92e95a5bdc44c2a9e72b446bd552d30fa551def307f098e5e09a05628091653c5e68e',
        },
        'pcap_1_10_4' => {
            'centos:7'            => 'a62075ea4c5ec3d4a758152ebd589023bdcf30f348dd4bd7576f2f5b7da51801e456f2d15ec4d782edad5e6f939c8119f6eb1b1c165314e8e1f2cf8791e7cbe1',

            'centos:8'            => 'c7aa10be977d84d81ed9823df4ddd86bd2b50f8311dc9d0bb849d3bf99e45ec2eb6372e6d328d063100f630d31adc4f1dc9aca792bfcc4498b5908298647bb64',
            'centos:aarch64:8'    => '8d78ee65dcb571988b2a94304c0601656d826d96c1c6b63eeeaf51db07b8947de3e0b874a311937e02e8695e82f15b0c8225084c4c4d7e9f229fa8dcab77c51c',

            'centos:9'            => '21bb87602b61bc439d3bc0b4c773c7982afb74fb547c1d15dc2c50b4e1764c1395042cfdabd170b34efaeb23d236bc30825b1aea95c26a0091959522e57bee65',
            'centos:aarch64:9'    => '95f832f1a186bfb05251eacd4c45700d2809f9eca4c0b9224631d1e3ab3089b772c397af6f56b267d51689cbbc11e91ccd7973092ab6c79a8429f25a426ca6a4',

            'debian:10'           => '41141b3bd7a33127d20bb5a400c6007fec432c0a9048e6f53c66c026972e9be7a91e1008c53534222e5adabbed3d02c3e8780fc1e6e9c45c39465d75efce66f9',

            'debian:11'           => '398f92099382c570df04057a93afa3fe4a80d40115b3ce8c898f9d859303f1b4972220bf13e44d72b30c4ea2287d6875d8831a65b9e17b5f62ce4c0c70dc48af',
            'debian:aarch64:11'   => 'edea9c2a6b55f166bc1f426cdc602aa773c99ea98b1fcbcdced628a6b43ddec29a62ff89e96d836c9cc6d7a6783ef3da8bc621f64d1ee429482849a8e4b2a160',

            'debian:12' => '2b5070f61591555a9c955881de229827bbf9f4fd29143ad6f38d67bb4812bab7e521a10d61cc2e31b635e89dfc8970b62bb91ee1447df159f869baf7c379b768',
            'debian:aarch64:12' => '329fb7592e1411c084c8d6f1dce6cd5f9c0732feba1d7058bc8b1d83e9d3db24ae7c1a3a5938901b5c9d104fa321d0c0907c7682a257b4f850429786f6dfee43',

            'ubuntu:16.04'        => '9c7768f34e3488ae0bab6f6ee9511011beb2b75e0cf5f6e2753792f574386ea53c2303166479cca525ebf46c7b320d256d744d0d7efe71fce6688a0d0eb0195c',
            'ubuntu:18.04'        => '540cadd6413d9df55a07e7ad3faf0b294056aa90cc9845f7e90b68dfc9eb2f24e7855931e852c2665c7ac4051d990e0cb087345373cb3636fc0da2543f71602d',

            'ubuntu:20.04'        => '9f1d32f2f9dd7ea54c8d9068cf4100e005c78faae9aed10d719fee74b4bd84701b32cfde3ba24e75cfed0e0949429a954443d9aa0268efb88a2a9747b7fad58b',
            'ubuntu:aarch64:20.04'=> '8dce49b6546d9cf6ebeb89ddcb7cfd5dcfe7ebe38f97fa31b377d5e839e20117003d45b10dbaf9ea75cee4c48ba49df506f2fdfef8805417b094f23d4ceec889',

            'ubuntu:22.04'        => 'e2f4d4de50770f3d3cffb4534fa53145f0261cff521249bef825094a046418a8b13d92a11e856e42f3fa54b53843a5e8afd4a1279e9b0277a62661bae93dc147',
            'ubuntu:aarch64:22.04'=> '7118bcede182fe35687e3a13f3b3497ea805b988c1304e22aaa8b0af3f1de37ba6fa963686585a4e5db46cff3cbc85d3bb3302af6cf68f32a2fd4a7b6034e47c',
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
