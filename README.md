
# Traefik
Install Traefik on host and configure backends ( *red/green/blue* ) to redirect HTTP requests by URL *Path Prefix* value - `/red`, `/green`, `/blue` .
Backends runs in docker containers on remote Docker-server by Docker API (use repository: **docker_systemd**).

## Variables
Variables defines in `./vars/default_vars.yml`, e.g.:

    traefik_version: "v2.x.x"
    ....
    traefik_download_url: "https://github.com/traefik/traefik/releases/download/{{ traefik_version}}/{{ traefik_archive_name }}"
    
    traefik_binary_dir: '/opt/traefik'
    traefik_config_dir: '/etc/traefik'
    ....
    container_name_prefix: "traefik_backend_"
    traefik_backend_list:
      - name: 'red'
        host: '<remote_docker_ip>'
        port: 8085
      - name: 'green'
        host: '<remote_docker_ip>'
        port: 8086
      - name: 'blue'
        host: '<remote_docker_ip>'
        port: 8087    
    ....
    and etc.
    
### Docker API Access (in `default_vars.yml` file)
    docker_api_url: "tcp://<remote_docker_ip>:2375"

### Attaching labels to docker containers (in `default_vars.yml` file)
     traefik_container_labels: >
       {
         "traefik.enable" : "true" ,
         ....
         ....
       }
please find in the **Deploy Traefik Server** section a detailed description.

## Prerequisites
### Preparation Docker server (if it's the first start)
- start deployment Docker server (from repository: **docker_systemd**): 

      $ ansible-playbook deploy_containers.yml

## Deploy Traefik Server
- start deployment Traefik as *systemd* service with configure backends ( *red/green/blue* ) : 

      $ ansible-playbook deploy_traefik.yml

### Traefik configuration files (static and dynamic)
The *Static Configuration* template file located at `./templates/traefik.toml.j2` defines:

+ the **entrypoints** Traefik will listen to
+ access to Traefik **Dashboard** in Secure Mode (default user and encrypted password: `user1`)

      http://traefik.example.com:8080/dashboard/

+ checking the Health of Traefik Instances (**Ping**):

      http://traefik.example.com:8080/ping

+ connections to **providers** (*Docker* and *File*)

      [providers.docker]
         endpoint = "{{ docker_api_url }}"        
         useBindPortIP = true
         exposedByDefault = false

      [providers.file]
         filename = "{{ traefik_config_dir }}/dynamic_conf.toml"

The *Dynamic Configuration* template file located at `./templates/dynamic_conf.toml.j2` defines configuration from *File provider*:

+ *Router* to access the dashboard in Secure Mode

      [http.routers.secure-api]
        entryPoints = ["traefik"]
        middlewares = ["dashboard-auth"]
        service = "api@internal"
        rule = "Host(`traefik.example.com`)"

+ BasicAuth *Middleware* with list of known users (default user and encrypted password: `user1`)

      [http.middlewares]
        [http.middlewares.dashboard-auth.basicAuth]
          users = [
            "user1:$apr1$54eGL2dN$UZmbgWUXKVt9.dvYSbWOg0",
          ]
         
### Docker provider configuration discovery in Traefik
When using Docker as a provider, Traefik uses *container labels* to retrieve its routing configuration. 
*Labels* are defined `traefik_container_labels` variable in `default_vars.yml` file: 
 
+ configure backends ( *red/green/blue* ) to redirect HTTP requests by URL *Path Prefix* value - `/red`, `/green`, `/blue` :

      "traefik.http.routers.container-{{ item.name }}.priority" : "99" ,
      "traefik.http.routers.container-{{ item.name }}.entrypoints" : "web" ,
      "traefik.http.routers.container-{{ item.name }}.rule" : "PathPrefix(`/{{ item.name }}`)" ,
      "traefik.http.routers.container-{{ item.name }}.middlewares" : "cont-{{ item.name }}-stripprefix" ,
      "traefik.http.middlewares.cont-{{ item.name }}-stripprefix.stripprefix.prefixes" : "/{{ item.name }}" ,
      "traefik.http.routers.container-{{ item.name }}.service" : "service-{{ item.name }}" ,
      "traefik.http.services.service-{{ item.name }}.loadbalancer.server.port" : "80" ,

+ configure HTTP round robin Load Balancing ( servers: *red/green/blue* ) incoming requests to `http://traefik.example.com` host :

      "traefik.http.routers.balance-router.entrypoints" : "web" ,
      "traefik.http.routers.balance-router.rule" : "Host(`traefik.example.com`)" ,
      "traefik.http.routers.balance-router.service" : "balance-service" ,
      "traefik.http.services.balance-service.loadbalancer.server.port" : "80"

## Remove backend containers ( *red/green/blue* ) from Remote Docker host

    $ ansible-playbook remove_backend_nodes.yml

***NOTE:*** Traefik Server must be up and running before. 
