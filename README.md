# monitor_hyperspace
hyperspace自动监控重启脚本


监控脚本放到root目录下，执行以下命令后台运行
nohup /root/monitor.sh >> /root/hyper.log 2>&1 &

监控脚本运行后会在root目录生成监控日志hyper.log，可以查看监控日志是否正常

如果需要重新运行，查看后台运行的进程
ps aux | grep monitor.sh

杀掉进程
kill 88908
