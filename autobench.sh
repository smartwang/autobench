#!/bin/bash


WORK_DIR=$(dirname $(readlink -f $0))
CPU_CORES=$(grep -c processor /proc/cpuinfo)


####################################
CPU_MAX_PRIME=${CPU_MAX_PRIME:-40000}
MEMORY_TOTAL_SIZE=${MEMORY_TOTAL_SIZE:-100G}
DISK_REQUESTS=${DISK_REQUESTS:-1000000}
MAX_TIME=${MAX_TIME:-28800}   # 单项测试时长限制(sec)
####################################

mkdir -p ${WORK_DIR}/{testfile,logs}
prepare_file(){
    cd ${WORK_DIR}/testfile
    sysbench --test=fileio --file-num=16 --file-total-size=10G cleanup 1>/dev/null 2>&1
    sysbench --test=fileio --file-num=16 --file-total-size=10G prepare 1>/dev/null 2>&1
}


####################
# 完成素数计算耗时，以此评估cpu性能, 最长测试不超过8小时，如果超过8小时，那就没什么性能可言了
cpu_benchmark(){
    CPU_SINGLE_RESULT=$(sysbench --test=cpu --max-time=28800 --cpu-max-prime=${CPU_MAX_PRIME} run)
    CPU_MULTI_RESULT=$(sysbench --test=cpu --max-time=28800 --cpu-max-prime=${CPU_MAX_PRIME} --num-threads=${CPU_CORES} run)

    CPU_SINGLE_TOTAL_TIME=$(echo "$CPU_SINGLE_RESULT" | grep 'total time:' | awk '{print $NF}')
    CPU_MULTI_TOTAL_TIME=$(echo "$CPU_MULTI_RESULT" | grep 'total time:' | awk '{print $NF}')

    echo -e "单核耗时\t\t\t\t\t\t\t${CPU_SINGLE_TOTAL_TIME}"
    echo -e "多核耗时\t\t\t\t\t\t\t${CPU_MULTI_TOTAL_TIME}"

}


# 测试内存吞吐量, 有单项最大测试时长限制
memory_benckmark(){
    THREAD_NUM=${1:-1}
    MEM_SEQ_READ_RESULT=$(sysbench --test=memory --num-threads=${THREAD_NUM} --memory-total-size=${MEMORY_TOTAL_SIZE} --max-time=${MAX_TIME} --memory-oper=read --memory-access-mode=seq run)
    MEM_SEQ_WRITE_RESULT=$(sysbench --test=memory --num-threads=${THREAD_NUM} --memory-total-size=${MEMORY_TOTAL_SIZE} --max-time=${MAX_TIME} --memory-oper=write --memory-access-mode=seq run)
    MEM_RND_READ_RESULT=$(sysbench --test=memory --num-threads=${THREAD_NUM} --memory-total-size=${MEMORY_TOTAL_SIZE} --max-time=${MAX_TIME} --memory-oper=read --memory-access-mode=rnd run)
    MEM_RND_WRITE_RESULT=$(sysbench --test=memory --num-threads=${THREAD_NUM} --memory-total-size=${MEMORY_TOTAL_SIZE} --max-time=${MAX_TIME} --memory-oper=write --memory-access-mode=rnd run)

    MEMORY_SEQ_READ_THROUGHPUT=$(echo "${MEM_SEQ_READ_RESULT}" | grep transferred | grep -oP '(?<=\().*(?=\s)' )
    MEMORY_SEQ_READ_TIME=$(echo "${MEM_SEQ_READ_RESULT}" | grep 'total time:' | awk '{print $NF}') 
    MEMORY_SEQ_WRITE_THROUGHPUT=$(echo "${MEM_SEQ_WRITE_RESULT}" | grep transferred | grep -oP '(?<=\().*(?=\s)' )
    MEMORY_SEQ_WRITE_TIME=$(echo "${MEM_SEQ_WRITE_RESULT}" | grep 'total time:' | awk '{print $NF}') 
    MEMORY_RND_READ_THROUGHPUT=$(echo "${MEM_RND_READ_RESULT}" | grep transferred | grep -oP '(?<=\().*(?=\s)' )
    MEMORY_RND_READ_TIME=$(echo "${MEM_RND_READ_RESULT}" | grep 'total time:' | awk '{print $NF}') 
    MEMORY_RND_WRITE_THROUGHPUT=$(echo "${MEM_RND_WRITE_RESULT}" | grep transferred | grep -oP '(?<=\().*(?=\s)' )
    MEMORY_RND_WRITE_TIME=$(echo "${MEM_RND_WRITE_RESULT}" | grep 'total time:' | awk '{print $NF}') 

    echo -e "${THREAD_NUM}线程数内存顺序读耗时\t\t\t\t\t\t${MEMORY_SEQ_READ_TIME}" 
    echo -e "${THREAD_NUM}线程数内存顺序读吞吐量\t\t\t\t\t${MEMORY_SEQ_READ_THROUGHPUT} MiB/s" 
    echo -e "${THREAD_NUM}线程数内存顺序写耗时\t\t\t\t\t\t${MEMORY_SEQ_WRITE_TIME}" 
    echo -e "${THREAD_NUM}线程数内存顺序写吞吐量\t\t\t\t\t${MEMORY_SEQ_WRITE_THROUGHPUT} MiB/s"
    echo -e "${THREAD_NUM}线程数内存随机读耗时\t\t\t\t\t\t${MEMORY_RND_READ_TIME}" 
    echo -e "${THREAD_NUM}线程数内存随机读吞吐量\t\t\t\t\t${MEMORY_RND_READ_THROUGHPUT} MiB/s"
    echo -e "${THREAD_NUM}线程数内存随机写耗时\t\t\t\t\t\t${MEMORY_RND_WRITE_TIME}" 
    echo -e "${THREAD_NUM}线程数内存随机写吞吐量\t\t\t\t\t${MEMORY_RND_WRITE_THROUGHPUT} MiB/s" 
}

# 磁盘性能测试，有单项最大测试时长限制，获取磁盘吞吐性能及IOPS
disk_benchmark(){
    FILE_BLOCK_SIZE=${1:-64k}
    prepare_file 
    DISK_SEQ_READ_RESULT=$(sysbench --test=fileio --file-total-size=10G --file-test-mode=seqrd --max-time=${MAX_TIME} --max-requests=${DISK_REQUESTS} --num-threads=16 --init-rng=on --file-num=16 --file-extra-flags=direct --file-fsync-freq=0 --file-block-size=${FILE_BLOCK_SIZE} run)
    DISK_SEQ_WRITE_RESULT=$(sysbench --test=fileio --file-total-size=10G --file-test-mode=seqwr --max-time=${MAX_TIME} --max-requests=${DISK_REQUESTS} --num-threads=16 --init-rng=on --file-num=16 --file-extra-flags=direct --file-fsync-freq=0 --file-block-size=${FILE_BLOCK_SIZE} run)

    prepare_file
    DISK_RND_READ_RESULT=$(sysbench --test=fileio --file-total-size=10G --file-test-mode=rndrd --max-time=${MAX_TIME} --max-requests=${DISK_REQUESTS} --num-threads=16 --init-rng=on --file-num=16 --file-extra-flags=direct --file-fsync-freq=0 --file-block-size=${FILE_BLOCK_SIZE} run)
    DISK_RND_WRITE_RESULT=$(sysbench --test=fileio --file-total-size=10G --file-test-mode=rndwr --max-time=${MAX_TIME} --max-requests=${DISK_REQUESTS} --num-threads=16 --init-rng=on --file-num=16 --file-extra-flags=direct --file-fsync-freq=0 --file-block-size=${FILE_BLOCK_SIZE} run)

    prepare_file
    DISK_RND_MIXED_RESULT=$(sysbench --test=fileio --file-total-size=10G --file-test-mode=rndrw --max-time=${MAX_TIME} --max-requests=${DISK_REQUESTS} --num-threads=16 --init-rng=on --file-num=16 --file-extra-flags=direct --file-fsync-freq=0 --file-block-size=${FILE_BLOCK_SIZE} run)

    DISK_SEQ_READ_IOPS=$(echo "${DISK_SEQ_READ_RESULT}" | grep 'reads/s:' | awk '{print $NF}' )
    DISK_SEQ_READ_THROUGHPUT=$(echo "${DISK_SEQ_READ_RESULT}" | grep 'read, MiB/s:' | awk '{print $NF}' )
    DISK_SEQ_WRITE_IOPS=$(echo "${DISK_SEQ_WRITE_RESULT}" | grep 'writes/s:' | awk '{print $NF}' )
    DISK_SEQ_WRITE_THROUGHPUT=$(echo "${DISK_SEQ_WRITE_RESULT}" | grep 'written, MiB/s:' | awk '{print $NF}' )

    DISK_RND_READ_IOPS=$(echo "${DISK_RND_READ_RESULT}" | grep 'reads/s:' | awk '{print $NF}' )
    DISK_RND_READ_THROUGHPUT=$(echo "${DISK_RND_READ_RESULT}" | grep 'read, MiB/s:' | awk '{print $NF}' )
    DISK_RND_WRITE_IOPS=$(echo "${DISK_RND_WRITE_RESULT}" | grep 'writes/s:' | awk '{print $NF}' )
    DISK_RND_WRITE_THROUGHPUT=$(echo "${DISK_RND_WRITE_RESULT}" | grep 'written, MiB/s:' | awk '{print $NF}' )

    DISK_RND_MIXED_READ_IOPS=$(echo "${DISK_RND_MIXED_RESULT}" | grep 'reads/s:' | awk '{print $NF}') 
    DISK_RND_MIXED_WRITE_IOPS=$(echo "${DISK_RND_MIXED_RESULT}" | grep 'writes/s:' | awk '{print $NF}') 
    DISK_RND_MIXED_READ_THROUGHPUT=$(echo "${DISK_RND_MIXED_RESULT}" | grep 'read, MiB/s:' | awk '{print $NF}') 
    DISK_RND_MIXED_WRITE_THROUGHPUT=$(echo "${DISK_RND_MIXED_RESULT}" | grep 'written, MiB/s:' | awk '{print $NF}') 

    echo -e "${FILE_BLOCK_SIZE}磁盘顺序读吞吐量\t\t\t\t\t\t${DISK_SEQ_READ_THROUGHPUT} MiB/s" 
    echo -e "${FILE_BLOCK_SIZE}磁盘顺序读IOPS\t\t\t\t\t\t${DISK_SEQ_READ_IOPS}/s" 
    echo -e "${FILE_BLOCK_SIZE}磁盘顺序写吞吐量\t\t\t\t\t\t${DISK_SEQ_WRITE_THROUGHPUT}MiB/s" 
    echo -e "${FILE_BLOCK_SIZE}磁盘顺序写IOPS\t\t\t\t\t\t${DISK_SEQ_WRITE_IOPS}/s" 
 
    echo -e "${FILE_BLOCK_SIZE}磁盘随机读吞吐量\t\t\t\t\t\t${DISK_RND_READ_THROUGHPUT} MiB/s" 
    echo -e "${FILE_BLOCK_SIZE}磁盘随机读IOPS\t\t\t\t\t\t${DISK_RND_READ_IOPS}/s" 
    echo -e "${FILE_BLOCK_SIZE}磁盘随机写吞吐量\t\t\t\t\t\t${DISK_RND_WRITE_THROUGHPUT} MiB/s" 
    echo -e "${FILE_BLOCK_SIZE}磁盘随机写IOPS\t\t\t\t\t\t${DISK_RND_WRITE_IOPS}/s" 
    echo -e "${FILE_BLOCK_SIZE}磁盘混合读写吞吐量\t\t\t\t\t\t${DISK_RND_MIXED_READ_THROUGHPUT}/${DISK_RND_MIXED_WRITE_THROUGHPUT}" 
    echo -e "${FILE_BLOCK_SIZE}磁盘混合读写IOPS\t\t\t\t\t\t${DISK_RND_MIXED_READ_IOPS}/${DISK_RND_MIXED_WRITE_IOPS}" 
}




debug_log(){
    echo "$CPU_SINGLE_RESULT" > ${WORK_DIR}/logs/CPU_SINGLE.log
    echo "$CPU_MULTI_RESULT"  > ${WORK_DIR}/logs/CPU_MULTI.log
    echo "$MEM_SEQ_READ_RESULT" >${WORK_DIR}/logs/MEM_SEQ_READ.log
    echo "$MEM_SEQ_WRITE_RESULT" > ${WORK_DIR}/logs/MEM_SEQ_WRITE.log
    echo "$MEM_RND_READ_RESULT" >${WORK_DIR}/logs/MEM_RND_READ.log
    echo "$MEM_RND_WRITE_RESULT" >${WORK_DIR}/logs/MEM_RND_WRITE.log
    echo "$DISK_SEQ_READ_RESULT" >${WORK_DIR}/logs/DISK_SEQ_READ.log
    echo "$DISK_SEQ_WRITE" >${WORK_DIR}/logs/DISK_SEQ_WRITE.log
    echo "$DISK_RND_READ_RESULT" >${WORK_DIR}/logs/DISK_RND_READ.log
    echo "$DISK_RND_WRITE_RESULT" >${WORK_DIR}/logs/DISK_RND_WRITE.log
    echo "$DISK_RND_MIXED_RESULT" >${WORK_DIR}/logs/DISK_RND_MIXED.log
}

{
    cpu_benchmark
    echo
    memory_benckmark
    echo
    memory_benckmark 16
    echo
    disk_benchmark 16k  
    echo
    disk_benchmark 64k
    debug_log
} | tee ${WORK_DIR}/logs/benchmark_$(date +%s).log

