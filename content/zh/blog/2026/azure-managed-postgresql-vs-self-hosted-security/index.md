---
title: "使用 Azure 托管 PostgreSQL 降低自建数据库的安全风险"
description: 
publishdate: 2026-08-14
attribution: "Wilson Wu"
tags: [azure,pg,postgresql,vm,security,malware,incident]
---

## 问题的背景

![PostgreSQL 安全问题](1-overview.png)

最近，一台部署在 Azure 上的 Linux 服务器突然出现 CPU 持续 100% 的情况。排查后发现，服务器上存在一个以 `postgres` 用户身份运行的恶意程序，并通过 `cron` 定时任务维持运行。

这台服务器上的 PostgreSQL：

- 没有通过 Azure NSG 向公网开放 `5432`；
- 没有被当前业务使用；
- 业务实际使用的是本机 MySQL；
- 但 PostgreSQL 服务仍然安装并运行；
- 系统中保留了 `postgres` 用户、主目录、cron 和历史脚本。

这次事件说明：

> PostgreSQL 没有向公网开放，并不代表服务器上与 PostgreSQL 相关的组件完全没有风险。

需要特别说明的是，目前的证据只能证明恶意程序利用了 `postgres` 操作系统用户及其目录进行持久化，**不能证明攻击者一定是通过 PostgreSQL 的 5432 端口进入服务器的**。初始入口也可能是历史配置、SSH、Web 应用、容器、旧镜像或其他漏洞。

如果生产环境确实需要 PostgreSQL，但没有必须自建数据库服务器的特殊要求，建议优先使用：

> **Azure Database for PostgreSQL，并通过私有网络访问，关闭公共网络入口。**

这样可以减少自建数据库所带来的操作系统用户、SSH、cron、systemd、补丁、备份和主机入侵等风险。

## 发现问题：服务器 CPU 持续占满

最初是在服务器上执行 `htop` 时发现异常。

![服务器 htop 中 CPU 占用异常](2-htop.png)

从截图中可以看到：

- 服务器共有 4 个 CPU 核心；
- 4 个核心全部达到 `100%`；
- Load Average 长期维持在 4 左右；
- 多个进程以 `postgres` 用户运行；
- 进程名称为随机字符串 `dzZ7yVrxv7`；
- 单个进程的 CPU 使用率超过 `200%`；
- 进程占用了大量内存。

进一步执行：

```bash
sudo ps -eo user,pid,ppid,lstart,etime,%cpu,%mem,stat,comm,args \
  --sort=-%cpu | head -20
```

其中一个主要进程如下：

```text
USER       PID   PPID  %CPU  %MEM  STAT  COMMAND
postgres   9918     1   377  29.8  Ssl   dzZ7yVrxv7
```

这不是正常的 PostgreSQL 进程。

正常情况下，PostgreSQL 进程名称通常类似：

```text
postgres
postgres: checkpointer
postgres: background writer
postgres: walwriter
postgres: autovacuum launcher
```

而本次进程具有以下异常特征：

- 名称为随机字符串；
- 以 `postgres` 用户运行；
- CPU 使用率接近 4 个核心；
- 父进程已经变成 PID 1；
- 内存占用异常高。

因此，初步判断这不是正常数据库负载，而是疑似挖矿程序或其他恶意程序。

## 分析问题：确认恶意程序来源

### 1. 检查进程真实文件

Linux 进程名称可以被修改或伪装，所以不能只看 `COMMAND`，需要检查 `/proc/<PID>/exe`。

执行：

```bash
sudo sh -c '
echo "EXE:"
ls -l /proc/9918/exe

echo "CWD:"
ls -l /proc/9918/cwd

echo "CMDLINE:"
tr "\0" " " < /proc/9918/cmdline
echo

echo "CGROUP:"
cat /proc/9918/cgroup
'
```

输出如下：

```text
EXE:
/proc/9918/exe -> /dev/shm/gJppJl6TbG (deleted)

CWD:
/proc/9918/cwd -> /var/lib/postgresql

CMDLINE:
dzZ7yVrxv7

CGROUP:
0::/system.slice/cron.service
```

这几项信息非常关键。

### 可执行文件位于 `/dev/shm`

真实程序路径为：

```text
/dev/shm/gJppJl6TbG
```

`/dev/shm` 是基于内存的临时文件系统。恶意程序经常将文件下载到这里，再从内存文件系统中执行，以减少在磁盘上的痕迹。

### 原文件已经被删除

路径末尾显示：

```text
(deleted)
```

说明程序启动后，磁盘上的原文件已被删除。但由于进程仍然持有该文件，程序依然可以继续运行。

这种“启动后删除自身”的行为是常见的恶意程序隐藏手段。

### 工作目录属于 PostgreSQL 用户

进程工作目录是：

```text
/var/lib/postgresql
```

这说明恶意程序与 `postgres` 用户的主目录有关。

### 进程由 cron 启动

cgroup 显示：

```text
/system.slice/cron.service
```

这说明程序是通过定时任务启动的。

### 2. 从运行中的进程保存样本

因为原始文件已经被删除，如果立即结束进程，可能无法再提取样本。因此先从 `/proc` 保存程序：

```bash
sudo mkdir -p /root/incident
sudo chmod 700 /root/incident

sudo cp -L /proc/9918/exe \
  /root/incident/suspect-9918.bin

sudo chmod 600 \
  /root/incident/suspect-9918.bin
```

检查文件类型：

```bash
sudo file /root/incident/suspect-9918.bin
```

结果如下：

```text
ELF 64-bit LSB shared object, x86-64,
statically linked, no section header
```

计算 SHA-256：

```bash
sudo sha256sum /root/incident/suspect-9918.bin
```

得到：

```text
d32f9eef63c496a146a6a811677dd27e337db993d6f1a4b1af145c3135d391b3
```

该文件具有以下特征：

- 随机文件名；
- 位于 `/dev/shm`；
- 静态链接；
- 没有节区表；
- 启动后删除原文件；
- 持续占用全部 CPU。

这些行为进一步证明它不是正常的 PostgreSQL 组件。

### 3. 检查 PostgreSQL 用户的定时任务

由于进程是从 `cron.service` 启动的，继续检查 `postgres` 用户的 crontab：

```bash
sudo crontab -u postgres -l
```

发现如下任务：

```cron
24 * * * * /var/lib/postgresql/.dbus-XGodM5jOyL
```

该任务会在每小时第 24 分钟执行一次隐藏脚本：

```text
/var/lib/postgresql/.dbus-XGodM5jOyL
```

文件名使用了以点开头的隐藏形式，并模仿了 D-Bus 的命名方式，很容易被误认为系统文件。

检查 cron 日志：

```bash
sudo journalctl -u cron.service \
  --since "2026-08-15 07:15:00" \
  --until "2026-08-15 09:15:00" \
  --no-pager
```

日志中可以看到：

```text
Aug 15 07:24:01 CRON: (postgres) CMD (/var/lib/postgresql/.dbus-XGodM5jOyL)
Aug 15 08:24:01 CRON: (postgres) CMD (/var/lib/postgresql/.dbus-XGodM5jOyL)
```

这证明恶意脚本至少在 `07:24` 和 `08:24` 被执行过。

### 4. 分析恶意启动脚本

检查文件：

```bash
sudo file /var/lib/postgresql/.dbus-XGodM5jOyL
sudo stat /var/lib/postgresql/.dbus-XGodM5jOyL
sudo sha256sum /var/lib/postgresql/.dbus-XGodM5jOyL
```

结果显示它是一个 Bash 脚本：

```text
Bourne-Again shell script, ASCII text executable,
with very long lines
```

对应 SHA-256：

```text
36b1dcf43876f55aae2b8be7dada848b41f60ec61cd4ca7ab2a1278193f286f0
```

这份脚本负责下载、启动或恢复恶意程序，也是恶意进程能够周期性出现的主要持久化机制。

如果只结束高 CPU 进程，而不清理这条 cron，恶意程序会在下一个小时的第 24 分钟再次出现。

### 5. 在用户目录中发现第二个恶意下载器

停止并卸载 PostgreSQL 后，我继续检查 `/var/lib/postgresql` 的残留文件：

```bash
sudo find /var/lib/postgresql \
  -xdev -maxdepth 10 -ls
```

发现了另一个可疑文件：

```text
/var/lib/postgresql/.config/systemd/user/
└── systemd-tmpfiles-cleanup/
    └── systemd-tmpfiles-cleanup-TNWow7.sh
```

这个文件使用了：

```text
systemd-tmpfiles-cleanup
```

作为目录名，试图伪装成正常的 systemd 临时文件清理组件。

检查文件类型和哈希：

```bash
sudo file \
  /var/lib/postgresql/.config/systemd/user/systemd-tmpfiles-cleanup/systemd-tmpfiles-cleanup-TNWow7.sh

sudo sha256sum \
  /var/lib/postgresql/.config/systemd/user/systemd-tmpfiles-cleanup/systemd-tmpfiles-cleanup-TNWow7.sh
```

结果为：

```text
Bourne-Again shell script, ASCII text executable,
with very long lines
```

SHA-256：

```text
9962de5e0c68ea6e85879c5f62f2d0806360dbe186dc15e1d59abf8e4209de11
```

脚本内容经过 Base64 编码，末尾直接执行：

```bash
base64 -d | bash
```

解码后的逻辑显示，它具备以下行为：

- 通过 Tor、SOCKS5 或 Tor2web 连接外部地址；
- 获取服务器公网 IP；
- 收集当前用户名、主机名和内核版本；
- 读取机器 ID；
- 从外部下载其他程序；
- 在 `/dev/shm`、`/tmp`、`/var/tmp` 等目录测试和执行文件；
- 启动程序后删除临时文件。

这已经不只是一个单纯的高 CPU 进程，而是一套包含下载、执行、隐藏和持久化能力的恶意程序。

## 为什么 PostgreSQL 没有开放公网端口，仍然存在风险？

Azure 网络安全组当时只允许公网访问：

- TCP 22；
- TCP 80；
- TCP 443。

并没有允许公网直接访问 PostgreSQL 的 `5432` 端口。

但检查服务器本机监听状态时发现：

```bash
sudo ss -lntp | grep ':5432'
```

输出为：

```text
LISTEN 0 244 0.0.0.0:5432 0.0.0.0:*
LISTEN 0 244 [::]:5432    [::]:*
```

这说明 PostgreSQL 在操作系统层面监听了所有 IPv4 和 IPv6 网卡。

虽然 Azure NSG 没有向公网放行 `5432`，但以下风险依然存在。

### 1. 同一虚拟网络中的主机仍可能访问

Azure NSG 默认存在 `AllowVnetInBound` 规则，同一虚拟网络中的其他服务器可能访问该端口。

如果同一 VNet 内的其他服务器被入侵，攻击者就可能通过内网继续攻击数据库服务器。

### 2. 本机应用或容器仍可能访问

即使公网无法连接，服务器本机运行的以下组件仍然可能访问 PostgreSQL：

- Web 应用；
- Docker 容器；
- CI/CD Agent；
- 其他被攻陷的服务；
- 本机恶意程序。

网络安全组无法阻止服务器本机进程访问本机数据库。

### 3. 风险不只来自数据库端口

本次恶意程序的实际持久化位置是：

- `postgres` 用户的 crontab；
- `/var/lib/postgresql` 用户目录；
- 用户级 systemd 配置目录；
- `/dev/shm` 临时执行目录。

即使 PostgreSQL 服务停止，只要这些用户、目录和定时任务仍然存在，恶意程序就可能继续运行。

所以，数据库的安全边界不只是 `5432` 端口，还包括：

- 操作系统账户；
- 数据目录；
- 用户主目录；
- cron；
- systemd；
- SSH；
- 软件包；
- 配置文件；
- 历史镜像和备份。

### 4. 未使用的软件往往更容易被忽略

这台服务器的业务实际使用 MySQL，PostgreSQL 并没有业务用途。

由于“不使用”，它反而容易长期处于以下状态：

- 没有人检查配置；
- 没有人检查系统用户；
- 没有人检查数据库日志；
- 没有人检查用户的 cron；
- 没有人检查相关目录；
- 没有人确认是否仍然需要；
- 没有人关注其补丁和版本。

因此：

> 未使用但仍然安装和运行的软件，并不是备用能力，而是未被管理的攻击面。

## 解决问题：清除恶意程序并卸载 PostgreSQL

### 1. 暂停恶意进程

取证完成后，先暂停进程：

```bash
sudo kill -STOP 9918
```

检查进程状态：

```bash
ps -p 9918 \
  -o user,pid,ppid,%cpu,%mem,stat,comm,args
```

状态中出现 `T`，说明进程已暂停。

暂停的好处是：

- 立即停止继续占用 CPU；
- 暂时停止潜在网络行为；
- 保留进程，便于继续调查；
- 避免在完成取证前丢失内存中的样本。

### 2. 备份并删除恶意 cron

先保存 crontab：

```bash
sudo crontab -u postgres -l \
  > /root/incident/postgres-crontab.txt
```

然后删除：

```bash
sudo crontab -u postgres -r
```

确认已删除：

```bash
sudo crontab -u postgres -l
```

预期输出：

```text
no crontab for postgres
```

### 3. 隔离恶意启动脚本

先备份脚本：

```bash
sudo cp -a \
  /var/lib/postgresql/.dbus-XGodM5jOyL \
  /root/incident/cron-payload
```

再从原位置移走：

```bash
sudo mv \
  /var/lib/postgresql/.dbus-XGodM5jOyL \
  /root/incident/original-dbus-XGodM5jOyL
```

限制证据文件权限：

```bash
sudo chown root:root \
  /root/incident/original-dbus-XGodM5jOyL \
  /root/incident/cron-payload

sudo chmod 600 \
  /root/incident/original-dbus-XGodM5jOyL \
  /root/incident/cron-payload
```

### 4. 结束恶意进程

确认恶意 cron 和启动脚本已隔离后，结束进程：

```bash
sudo kill -KILL 9918
```

检查进程是否消失：

```bash
ps -p 9918 \
  -o user,pid,ppid,%cpu,%mem,stat,comm,args
```

随后查看系统负载：

```bash
uptime
```

清理后的负载变为：

```text
load average: 0.36, 2.71, 3.68
```

1 分钟负载已经从 4 以上下降到 `0.36`。

5 分钟和 15 分钟负载仍然较高是正常的，因为它们反映的是一段时间内的平均值，会逐渐下降。

### 5. 停止并禁用 PostgreSQL

因为业务并不使用 PostgreSQL，所以先停止并禁止开机启动：

```bash
sudo systemctl disable --now postgresql
```

确认服务状态：

```bash
systemctl status postgresql --no-pager
```

确认端口不再监听：

```bash
sudo ss -lntp | grep ':5432' \
  || echo "5432 端口未监听"
```

最终结果为：

```text
5432 端口未监听
```

### 6. 卸载 PostgreSQL

确认业务没有受到影响后，卸载 PostgreSQL 相关软件包：

```bash
sudo apt-get purge -y \
  postgresql \
  postgresql-14 \
  postgresql-client-14 \
  postgresql-client-common \
  postgresql-common \
  postgresql-contrib
```

需要注意：

> 卸载软件包不等于完成恶意程序清理。

还应继续检查以下位置：

```text
/var/lib/postgresql
/etc/postgresql
/etc/postgresql-common
/var/spool/cron
/tmp
/var/tmp
/dev/shm
/home/*/.config/systemd
```

本次发现的第二个恶意下载器，就是在卸载 PostgreSQL 后检查残留目录时找到的。

### 7. 隔离第二个恶意下载器

将伪装成 systemd 清理任务的脚本移入证据目录：

```bash
sudo mv \
  /var/lib/postgresql/.config/systemd/user/systemd-tmpfiles-cleanup/systemd-tmpfiles-cleanup-TNWow7.sh \
  /root/incident/systemd-tmpfiles-cleanup-TNWow7.sh
```

限制权限：

```bash
sudo chown root:root \
  /root/incident/systemd-tmpfiles-cleanup-TNWow7.sh

sudo chmod 600 \
  /root/incident/systemd-tmpfiles-cleanup-TNWow7.sh
```

然后搜索是否存在同类文件：

```bash
sudo grep -RIlE \
  'TNWow7|XGodM5jOyL|tor2socks|tor2web|relay\.tor2socks' \
  /etc \
  /var/spool/cron \
  /var/lib/postgresql \
  /tmp \
  /var/tmp \
  /dev/shm \
  /home \
  2>/dev/null
```

## Azure 网络安全配置整改

### 1. 不需要删除不存在的 5432 入站规则

Azure NSG 中原本没有允许公网访问 `5432` 的规则，所以不需要专门删除 PostgreSQL 入站规则。

停止并卸载 PostgreSQL 后，本机也已经不再监听 `5432`。

但是，不能因为 NSG 没有开放 `5432` 就认为服务器已经安全。

### 2. 收紧 SSH 入站范围

排查过程中，SSH 日志中出现了多个公网 IP 对 `postgres` 用户进行密码尝试：

```text
Failed password for postgres from 172.83.83.194
Failed password for postgres from 101.36.110.41
```

这些记录显示的是失败登录，不能说明对方已经通过 SSH 登录成功。但它们说明服务器的 SSH 正在被公网持续扫描。

原 Azure SSH 规则为：

```text
Source: Any
Destination port: 22
Action: Allow
```

建议改为：

```text
Source: 管理员固定公网 IP/32
Destination port: 22
Protocol: TCP
Action: Allow
```

更安全的方式包括：

- Azure Bastion；
- VPN；
- Just-In-Time VM Access；
- 禁止 SSH 密码登录；
- 只使用 SSH Key；
- 禁止 root 远程登录；
- 配置失败登录告警。

### 3. 限制服务器出站访问

恶意脚本需要连接外部地址下载程序，而当时 Azure NSG 允许任意出站访问。

如果业务条件允许，应限制服务器的出站范围：

- 只允许必要的 DNS；
- 只允许必要的软件源；
- 只允许业务需要访问的 API；
- 使用 Azure Firewall 或集中式代理；
- 记录 DNS 和出站网络日志；
- 对 Tor、代理、矿池和异常域名建立告警。

仅限制入站流量是不够的。恶意程序一旦进入服务器，通常还需要通过出站网络下载载荷、连接控制服务器或矿池。

## 为什么建议使用 Azure 托管 PostgreSQL？

如果业务确实需要 PostgreSQL，建议优先使用：

```text
Azure Database for PostgreSQL
```

而不是直接在 Azure VM 上安装 PostgreSQL。

### 1. 减少操作系统层面的攻击面

在 VM 上自建 PostgreSQL，需要自行维护：

- Linux 操作系统；
- PostgreSQL 软件包；
- `postgres` 系统用户；
- SSH；
- cron；
- systemd；
- 数据目录权限；
- 安全补丁；
- 版本升级；
- 网络防火墙；
- 日志；
- 备份；
- 高可用；
- 恶意进程检测。

使用 Azure 托管 PostgreSQL 后，用户不会直接管理数据库所在主机的 root 权限，也不会在数据库主机上创建 cron、systemd 服务或运行 `/dev/shm` 中的程序。

这可以显著减少本次事件中出现的主机级风险。

### 2. 使用私有网络，关闭公网访问

建议采用以下网络架构：

```text
Azure VM / App Service / AKS
          |
      Private Network
          |
Azure Database for PostgreSQL
```

数据库应配置为：

- 禁止公共网络访问；
- 使用 Private Endpoint 或私有网络集成；
- 只允许应用所在子网访问；
- 不向公网开放数据库端口；
- 数据库管理也通过 VPN、Bastion 或受控网络完成。

### 3. 自动备份和维护

Azure 托管 PostgreSQL 可以提供：

- 自动备份；
- 时间点恢复；
- 高可用选项；
- 数据加密；
- 监控指标；
- 日志与告警；
- 平台维护；
- 安全更新；
- 版本支持。

这些能力可以降低因长期无人维护而产生的风险。

### 4. 责任边界更清晰

自建 PostgreSQL 经常出现这种情况：

> 为了测试临时安装，后来业务不用了，但服务、用户和目录一直留在服务器上。

托管数据库的资源边界更加清晰：

- 需要时创建；
- 通过私有网络连接；
- 不再使用时导出数据；
- 删除数据库实例；
- 删除访问权限和私有连接；
- 不会在业务 VM 上留下数据库系统用户和历史脚本。

### 5. 托管服务并不等于绝对安全

Azure 托管 PostgreSQL 可以减少操作系统和基础设施维护风险，但仍需要正确管理：

- 数据库账号；
- 强密码或身份认证；
- 最小权限；
- 网络访问范围；
- SQL 注入；
- 连接字符串；
- Azure Key Vault；
- 日志审计；
- 数据加密；
- 应用依赖；
- 凭据轮换。

正确的理解是：

> Azure 托管 PostgreSQL 缩小了需要自己负责的安全范围，但不会消除应用和账号层面的安全责任。

## 本次事件的 IOC

以下指标可用于内部服务器排查。

### 可疑进程及文件名

```text
dzZ7yVrxv7
gJppJl6TbG
.dbus-XGodM5jOyL
systemd-tmpfiles-cleanup-TNWow7.sh
```

### SHA-256

恶意 ELF 程序：

```text
d32f9eef63c496a146a6a811677dd27e337db993d6f1a4b1af145c3135d391b3
```

恶意 cron 启动脚本：

```text
36b1dcf43876f55aae2b8be7dada848b41f60ec61cd4ca7ab2a1278193f286f0
```

恶意下载器：

```text
9962de5e0c68ea6e85879c5f62f2d0806360dbe186dc15e1d59abf8e4209de11
```

### 行为特征

- 以 `postgres` 用户运行；
- 从 `/dev/shm` 执行随机名称文件；
- 启动后删除原文件；
- 利用用户 crontab 定时启动；
- Base64 解码后直接交给 Bash 执行；
- 使用 Tor、SOCKS5 或 Tor2web；
- 收集公网 IP、用户名、主机名和机器 ID；
- 从外部下载其他程序；
- 在 `/tmp`、`/var/tmp` 和 `/dev/shm` 中执行程序；
- 持续占用全部 CPU；
- 伪装成 D-Bus 或 systemd 组件。

## 最终总结

本次事件从表面上看，是一次服务器 CPU 占用过高的问题。

但深入排查后发现，真正的问题包括：

- 以 `postgres` 用户运行的恶意程序；
- 位于 `/dev/shm` 的随机 ELF 文件；
- `postgres` 用户的恶意 cron；
- `/var/lib/postgresql` 下的隐藏启动脚本；
- 伪装成 systemd 组件的恶意下载器；
- 可连接 Tor 和外部下载地址的恶意逻辑。

最值得关注的是：

> 这台服务器没有通过 Azure NSG 向公网开放 PostgreSQL 的 5432 端口，而且业务也没有使用 PostgreSQL，但与 PostgreSQL 有关的系统用户、主目录、cron 和残留文件仍然构成了安全风险。

当然，现有证据并不能证明初始入侵入口就是 PostgreSQL。恶意程序使用 `postgres` 用户运行，不等于攻击者一定通过 PostgreSQL 端口进入服务器。

但这次事件依然说明了几个重要原则。

### 第一，不使用的服务应立即停止和卸载

不要因为“没有向公网开放”就长期保留闲置服务。

不使用的软件应当：

- 停止服务；
- 禁止开机启动；
- 卸载软件包；
- 检查系统用户；
- 检查 cron；
- 检查 systemd；
- 检查残留目录和脚本。

### 第二，云安全组不是唯一安全边界

NSG 没有开放 `5432`，只能说明公网无法通过该规则直接连接数据库，不能防止：

- 内网访问；
- 本机访问；
- 容器访问；
- 历史持久化；
- 用户级 cron；
- 本机恶意程序；
- SSH 和应用漏洞。

### 第三，生产 PostgreSQL 优先使用 Azure 托管服务

如果没有必须自建数据库服务器的明确需求，建议使用：

> **Azure Database for PostgreSQL + 私有网络 + 禁止公共访问。**

这样可以减少数据库主机操作系统、SSH、系统用户、cron、systemd、补丁、备份和高可用等方面的维护风险。

### 第四，杀掉恶意进程不等于完成安全恢复

结束高 CPU 进程只解决了当前资源占用问题，还应继续：

- 查找持久化；
- 调查入侵入口；
- 检查 SSH 成功登录记录；
- 检查 Web 应用和容器；
- 轮换服务器上的全部凭据；
- 检查同一 VNet 中的其他主机；
- 保存日志和磁盘快照；
- 必要时从可信镜像重建服务器。

最终可以将这次事件概括为一句话：

> **不使用的数据库不要留在服务器上；需要 PostgreSQL 时，优先使用 Azure 托管 PostgreSQL，并通过私有网络访问。**
