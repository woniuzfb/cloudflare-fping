# cfping.sh

> ping [fping] all cloudflare ips to find the best ip

## Usage

Invoking `cfping.sh -h` prints usage information:

    $ cfping.sh -h
    $ usage: cfping.sh -c [-p 2000] [-s 5] [-g 1] [-m 500]
    $         -c     ping [fping] all cloudflare ips to find the best ip
    $         -p <x> sets the time in milliseconds that fping waits between successive
    $                packets to an individual target (default is 2000, minimum is 10)
    $         -s <x> set the number of request packets to send to each target (default is 5)
    $         -g <x> the minimum amount of time (in milliseconds) between sending a
    $                ping packet to any target (default is 1, minimum is 1)
    $         -l     show cloudflare ip location
    $         -m     you may want to use this according to system resources limit 
                     larger number faster result (default is 500)

    ---

    $ usage: cfping.sh [options] <start> <end>
    $         -n <x> set the number of addresses to print (<end> must not be set)
    $         -f <x> set the format of addresses (hex, dec, or dot)
    $         -i <x> set the increment to 'x'
    $         -h     display this help message and exit
    $         -v     display the version number and exit

## ping cloudflare 所有的 IP 找到最优 IP

### 使用方法

cfping.sh -c

- 1分钟就可以得到结果
- 所有的 ip 都在 ip_sorted
- 如果要显示 ip 位置, 加参数 -l
- mac / linux 测试通过

---

## Credits

[fping](https://github.com/schweikert/fping)
[prips.sh](https://github.com/honzahommer/prips.sh)

© 2020 MTimer. MIT license.
