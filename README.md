# fritzbox-bandwidth-monitor
Monitor your fritz.box with mrtg using docker

Build:
````
docker build -t fritzbox-bandwidth-monitor .
````

Run with "docker":
```
docker run -d -p 80:80 fritzbox-bandwidth-monitor 
````

Or using docker-compose:
```
  fritzbox-bandwidth-monitor:
    image: fritzbox-bandwidth-monitor
    container_name: fritzbox-bandwidth-monitor
    ports:
      - 80:80
    restart: unless-stopped
```

Point your Browser to http://localhost/fritzbox.html and view your traffic stats. Cron runs every five minutes and updates the html data within the container.

![Example image]
(images/example.png)

