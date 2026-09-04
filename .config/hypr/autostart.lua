-- Extra autostart processes.
o.launch_on_start("bash", "/home/harrashy/.local/bin/disable-lock-on-ac.sh")
o.launch_on_start("bongocat", "--watch-config")
o.launch_on_start("hyprsunset", "-t", "4000")

-- o.launch_on_start("my-service")
