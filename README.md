# autobench
autorun sysbench

默认的测试参数：

  CPU_MAX_PRIME: 40000
  MEMORY_TOTAL_SIZE: 100G
  DISK_REQUESTS: 1000000
  MAX_TIME: 28800


可通过设置环境变量来改变上述测试的参数

example:

  CPU_MAX_PRIME=400 MEMORY_TOTAL_SIZE=1G DISK_REQUESTS=10000 MAX_TIME=5 bash autobench.sh
