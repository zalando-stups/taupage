Dec  1 15:06:16 ip-172-31-19-255 ntpd[1853]: Listen normally on 5 lo ::1 UDP 123
Dec  1 15:06:16 ip-172-31-19-255 ntpd[1853]: Listen normally on 6 eth0 fe80::4d3:42ff:fe75:e909 UDP 123
Dec  1 15:06:16 ip-172-31-19-255 ntpd[1853]: peers refreshed
Dec  1 15:06:16 ip-172-31-19-255 ntpd[1853]: Listening on routing socket on fd #23 for interface updates
Dec  1 15:06:16 ip-172-31-19-255 taupage-init: INFO: Writing dockercfg
Dec  1 15:06:16 ip-172-31-19-255 taupage-init: INFO: Successfully placed dockercfg
Dec  1 15:06:16 ip-172-31-19-255 taupage-init: mdadm: cannot open /dev/md/sampleraid0: No such file or directory
Dec  1 15:06:16 ip-172-31-19-255 taupage-init: mdadm: cannot open /dev/xvdb: Device or resource busy
Dec  1 15:06:17 ip-172-31-19-255 taupage-init: Traceback (most recent call last):
Dec  1 15:06:17 ip-172-31-19-255 taupage-init:   File "./init.d/10-prepare-disks.py", line 223, in <module>
Dec  1 15:06:17 ip-172-31-19-255 taupage-init:     main()
Dec  1 15:06:17 ip-172-31-19-255 taupage-init:   File "./init.d/10-prepare-disks.py", line 216, in main
Dec  1 15:06:17 ip-172-31-19-255 taupage-init:     handle_volumes(args, config)
Dec  1 15:06:17 ip-172-31-19-255 taupage-init:   File "./init.d/10-prepare-disks.py", line 190, in handle_volumes
Dec  1 15:06:17 ip-172-31-19-255 taupage-init:     handle_raid_volumes(volumes.get("raid"))
Dec  1 15:06:17 ip-172-31-19-255 taupage-init:   File "./init.d/10-prepare-disks.py", line 177, in handle_raid_volumes
Dec  1 15:06:17 ip-172-31-19-255 taupage-init:     create_raid_device(raid_device, raid_config)
Dec  1 15:06:17 ip-172-31-19-255 taupage-init:   File "./init.d/10-prepare-disks.py", line 168, in create_raid_device
Dec  1 15:06:17 ip-172-31-19-255 taupage-init:     subprocess.check_call(call)
Dec  1 15:06:17 ip-172-31-19-255 taupage-init:   File "/usr/lib/python3.4/subprocess.py", line 557, in check_call
Dec  1 15:06:17 ip-172-31-19-255 taupage-init:     raise CalledProcessError(retcode, cmd)
Dec  1 15:06:17 ip-172-31-19-255 taupage-init: subprocess.CalledProcessError: Command '['mdadm', '--create', '/dev/md/sampleraid0', '--run', '--level=1', '--raid-devices=2', '/dev/xvdb', '/dev/xvdc']' returned non-zero exit status 2
