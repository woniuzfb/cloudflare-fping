# cfping.sh

> ping [fping] all cloudflare ips to find the best ip

## Usage

Invoking `cfping.sh -h` prints usage information:

    $ cfping.sh -h
    $ usage: 
    $      cfping.sh -c [-p 2000] [-s 5] [-g 1] [-m 500]
    $         -c     ping [fping] all cloudflare ips to find the best ip
    $         -p <x> sets the time in milliseconds that fping waits between successive
    $                packets to an individual target (default is 2000, minimum is 10)
    $         -s <x> set the number of request packets to send to each target (default is 5)
    $         -g <x> the minimum amount of time (in milliseconds) between sending a
    $                ping packet to any target (default is 1, minimum is 1)
    $         -l     show cloudflare ip location
    $         -m <x> you may want to use this according to system resources limit 
                     larger number faster result (default is 500)

    ---

    $     cfping.sh -d [-L https://domain.com/xxx] [-N 100] [-P 10] [-I ip]
    $         -d     speed test (default testing best 100 IPs unless -I used)
    $         -L <x> set the file link to test (default: https://speed.cloudflare.com/__down?bytes=100001000)
    $                the domain of this link must have cname record on cloudflare
    $         -N <x> set the number of IPs to test (default is 100)
    $         -P <x> set the parallel number of speed test (default is 10)
    $         -I <x> specify an ip to test

    ---

    $     cfping.sh [options] <start> <end>
    $         -n <x> set the number of addresses to print (<end> must not be set)
    $         -f <x> set the format of addresses (hex, dec, or dot)
    $         -i <x> set the increment to 'x'
    $         -h     display this help message and exit
    $         -v     display the version number and exit

## ping cloudflare 所有的 IP 找到最优 IP 并测速

### 使用方法

`cfping.sh -c`

- 1分钟就可以得到结果
- 所有的 ip 都在 ip_sorted
- 如果要显示 ip 位置, 加参数 `-l`

`cfping.sh -d`

- 默认测速 100 个 ip
- 如果要自定义测速文件, 加参数 `-L`
  文件链接的域名必须在 cloudflare 有 cname 记录
- 如果测速单个指定 IP, 加参数 `-I`

部分网络无法分配到香港 ip, 建议更换其他网络

mac / linux 测试通过

---

## Credits

[fping](https://github.com/schweikert/fping)

[prips.sh](https://github.com/honzahommer/prips.sh)

[Inquirer.sh](https://github.com/tanhauhau/Inquirer.sh)

© 2020 MTimer. MIT license.
