

# 系统内核参数优化 For Database

针对PostgreSQL，可以对Linux操作系统进行调优，具体包括：

- IO优化：调度算法调优，预读参数
- 内存优化：关闭SWAP，关闭透明大页，关闭NUMA。
- 资源限制

```bash
optimize() {
	if (( "$#" == 1 )); then
		local datadir="$1"; shift
		local mem="$(free \
		     | awk '/Mem:/{print $2}')"
		local swap="$(free \
		     | awk '/Swap:/{print $2}')"

		cat > /etc/sysctl.conf <<- EOF
		# Database kernel optimisation
		fs.aio-max-nr = 1048576
		fs.file-max = 76724600
		kernel.sem = 4096 2147483647 2147483646 512000
		kernel.shmmax = $(( $mem * 1024 / 2 ))
		kernel.shmall = $(( $mem / 5 ))
		kernel.shmmni = 819200
		net.core.netdev_max_backlog = 10000
		net.core.rmem_default = 262144
		net.core.rmem_max = 4194304
		net.core.wmem_default = 262144
		net.core.wmem_max = 4194304
		net.core.somaxconn = 4096
		net.ipv4.tcp_max_syn_backlog = 4096
		net.ipv4.tcp_keepalive_intvl = 20
		net.ipv4.tcp_keepalive_probes = 3
		net.ipv4.tcp_keepalive_time = 60
		net.ipv4.tcp_mem = 8388608 12582912 16777216
		net.ipv4.tcp_fin_timeout = 5
		net.ipv4.tcp_synack_retries = 2
		net.ipv4.tcp_syncookies = 1
		net.ipv4.tcp_timestamps = 1
		net.ipv4.tcp_tw_recycle = 0
		net.ipv4.tcp_tw_reuse = 1
		net.ipv4.tcp_max_tw_buckets = 262144
		net.ipv4.tcp_rmem = 8192 87380 16777216
		net.ipv4.tcp_wmem = 8192 65536 16777216
		vm.dirty_background_bytes = 409600000
		net.ipv4.ip_local_port_range = 40000 65535
		vm.dirty_expire_centisecs = 6000
		vm.dirty_ratio = 80
		vm.dirty_writeback_centisecs = 50
		vm.extra_free_kbytes = 4096000
		vm.min_free_kbytes = 2097152
		vm.mmap_min_addr = 65536
		vm.swappiness = 0
		vm.overcommit_memory = 2
		vm.overcommit_ratio = $(( ( $mem - $swap ) * 100 / $mem ))
		vm.zone_reclaim_mode = 0
		EOF
		sysctl -p


		cat > /etc/security/limits.d/postgresql.conf <<- EOF
		postgres    soft    nproc       655360
		postgres    hard    nproc       655360
		postgres    hard    nofile      655360
		postgres    soft    nofile      655360
		postgres    soft    stack       unlimited
		postgres    hard    stack       unlimited
		postgres    soft    core        unlimited
		postgres    hard    core        unlimited
		postgres    soft    memlock     250000000
		postgres    hard    memlock     250000000
		EOF
		cat > /etc/security/limits.d/pgbouncer.conf <<- EOF
		pgbouncer    soft    nproc       655360
		pgbouncer    hard    nofile      655360
		pgbouncer    soft    nofile      655360
		pgbouncer    soft    stack       unlimited
		pgbouncer    hard    stack       unlimited
		pgbouncer    soft    core        unlimited
		pgbouncer    hard    core        unlimited
		pgbouncer    soft    memlock     250000000
		pgbouncer    hard    memlock     250000000
		EOF
		cat > /etc/security/limits.d/pgpool.conf <<- EOF
		pgpool    soft    nproc       655360
		pgpool    hard    nofile      655360
		pgpool    soft    nofile      655360
		pgpool    soft    stack       unlimited
		pgpool    hard    stack       unlimited
		pgpool    soft    core        unlimited
		pgpool    hard    core        unlimited
		pgpool    soft    memlock     250000000
		pgpool    hard    memlock     250000000
		EOF
	fi
}

```

