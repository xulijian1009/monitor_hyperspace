#!/bin/bash
LOG_FILE="/root/aios-cli.log"
SCREEN_NAME="hyper"
LAST_RESTART=$(date +%s)
MIN_RESTART_INTERVAL=300
MAX_SAME_LOG_COUNT=20  # 最大相同日志计数

# 如果 LAST_RESTART 为空，则初始化为当前 UTC 时间
if [ -z "$LAST_RESTART" ]; then
    LAST_RESTART=$(date -u +%s)
fi

# 初始化计数器
same_log_count=0
last_log=""

while true; do
    # 获取当前本地时间的 UTC 时间戳
    current_time_utc=$(date -u +%s)  # 获取当前 UTC 时间戳
    
    # 获取最后四行日志
    last_lines=$(tail -n 4 "$LOG_FILE")
    
    # 输出日志行到终端（如果需要）并且记录日志到 hyper.log 文件，由 nohup 处理输出
    echo -e "$(date -u "+%Y-%m-%d %H:%M:%S"): 检查的最后四行日志：\n$last_lines"

    # 检查是否连续20次相同日志
    if [ "$last_log" == "$last_lines" ]; then
        same_log_count=$((same_log_count + 1))
    else
        same_log_count=0  # 如果是不同的日志，重置计数器
    fi

    # 更新记录的日志
    last_log="$last_lines"

    # 逐行处理日志，提取日期时间并转换为 UTC 时间戳
    log_time_utc=0
    while read -r line; do
        # 提取每行日志中的日期时间（假设格式为 [2025-01-18 17:51:23]）
        log_timestamp=$(echo "$line" | grep -oP '^\[\K[^\]]+')

        if [[ -n "$log_timestamp" ]]; then
            # 转换提取的日期时间为 UTC 时间戳
            log_time_utc=$(date -u -d "$log_timestamp" +%s)  # 将日志时间转换为 UTC 时间戳
        fi
    done <<< "$last_lines"

    # 确保 log_time_utc 被成功赋值并且大于0
    if [ $log_time_utc -gt 0 ]; then
        # 输出转换后的日志时间到终端（如果需要）并且记录日志到 hyper.log 文件，由 nohup 处理输出
        echo -e "$(date -u "+%Y-%m-%d %H:%M:%S"): 日志时间（UTC）: $(date -u -d @$log_time_utc "+%Y-%m-%d %H:%M:%S")"
        
        # 判断是否检测到错误，并且重启间隔满足条件
        if echo "$last_lines" | grep -q "Last pong received" || \
           echo "$last_lines" | grep -q "Sending reconnect signal" || \
           echo "$last_lines" | grep -q "Failed to authenticate" || \
           echo "$last_lines" | grep -q "Failed to connect to Hive" || \
           echo "$last_lines" | grep -q "Another instance is already running" || \
           echo "$last_lines" | grep -q "\"message\": \"Internal server error\""; then
           
            if [ $((current_time_utc - LAST_RESTART)) -gt $MIN_RESTART_INTERVAL ]; then
                echo -e "$(date -u "+%Y-%m-%d %H:%M:%S"): 检测到错误日志并且距离上次重启超过 $MIN_RESTART_INTERVAL 秒，正在重启服务..."

                # 先发送 Ctrl+C 停止当前运行的进程
                screen -S "$SCREEN_NAME" -X stuff $'\003'
                sleep 5

                # 执行 aios-cli kill 停止当前进程
                screen -S "$SCREEN_NAME" -X stuff "aios-cli kill\n"
                sleep 5

                # 清理旧日志
                echo -e "$(date -u "+%Y-%m-%d %H:%M:%S"): 清理旧日志..." > "$LOG_FILE"

                # 重新启动服务
                screen -S "$SCREEN_NAME" -X stuff "aios-cli start --connect >> /root/aios-cli.log 2>&1\n"

                # 更新最后重启时间
                LAST_RESTART=$current_time_utc
                echo -e "$(date -u "+%Y-%m-%d %H:%M:%S"): 服务已重启"
            else
                echo -e "$(date -u "+%Y-%m-%d %H:%M:%S"): 距离上次重启时间 [$(date -u -d @$LAST_RESTART "+%Y-%m-%d %H:%M:%S")] 小于 $MIN_RESTART_INTERVAL 秒，跳过重启。"
            fi
        fi
    else
        echo -e "$(date -u "+%Y-%m-%d %H:%M:%S"): 日志没有找到有效的时间戳，跳过检查。"
    fi


    # 确保 log_time_utc 被成功赋值并且大于0
    if [ $same_log_count -ge $MAX_SAME_LOG_COUNT ]; then
        echo -e "$(date -u "+%Y-%m-%d %H:%M:%S"): 连续 20 次检测到相同的错误日志，正在重启服务..."
        
        # 先发送 Ctrl+C 停止当前运行的进程
        screen -S "$SCREEN_NAME" -X stuff $'\003'
        sleep 5

        # 执行 aios-cli kill 停止当前进程
        screen -S "$SCREEN_NAME" -X stuff "aios-cli kill\n"
        sleep 5

        # 清理旧日志
        echo -e "$(date -u "+%Y-%m-%d %H:%M:%S"): 清理旧日志..." > "$LOG_FILE"

        # 重新启动服务
        screen -S "$SCREEN_NAME" -X stuff "aios-cli start --connect >> /root/aios-cli.log 2>&1\n"

        # 更新最后重启时间
        LAST_RESTART=$current_time_utc
        echo -e "$(date -u "+%Y-%m-%d %H:%M:%S"): 服务已重启"
        same_log_count=0  # 重启后重置计数器
    else
        echo -e "$(date -u "+%Y-%m-%d %H:%M:%S"): 第 $same_log_count 次监控到相同日志，系统设定 $MAX_SAME_LOG_COUNT 次后重启服务"
    fi

    # 每30秒检查一次
    sleep 30
done
