[[ ! -d ./data/example || ! -d ./data/default || ! -d ./data/user ]] && echo "Pull repository for fix this error!"
config_file="./config.conf"

function get_data(){
  domains=$(grep -E '^domain_lists\s*=' "$config_file" | awk -F '=' '{print $2}' | tr -d '[:space:]' | sed 's/,/ /g' | sed 's/"/ /g')
  hosts=$(grep -E '^host_lists\s*=' "$config_file" | awk -F '=' '{print $2}' | tr -d '[:space:]' | sed 's/,/ /g' | sed 's/"/ /g')
  [[ -d $(pwd)/domains ]] && mkdir -p $(pwd)/domains
  [[ -d $(pwd)/hosts ]] && mkdir -p $(pwd)/hosts
  echo "Download in proccess..."
  wget -q -P $(pwd)/domains/ $domains
  wget -q -P $(pwd)/hosts/ $hosts
  echo "Success download..."
  cat $(pwd)/domains/* > dmerg.txt
  cat $(pwd)/hosts/* > hmerg.txt
}

function generate(){
  if [[ $choosed == "domains" ]]; then
    if [[ ! -f domains.txt ]]; then
      get_data
    fi
    sed -i '/^#/d' dmerg.txt hmerg.txt
    sed -i '/^!/d' dmerg.txt hmerg.txt
    sed -i '/^$/d' dmerg.txt hmerg.txt
    sed -i 's/^127\.0\.0\.1 /*./g' dmerg.txt hmerg.txt
    sed -i 's/^0\.0\.0\.0 /*./g' dmerg.txt hmerg.txt
    cat dmerg.txt hmerg.txt > merger_domains.txt
    rm -f dmerg.txt hmerg.txt
    sort merger_domains.txt > domains.txt
    rm -f merger_domains.txt
    rm -rf $(pwd)/domains $(pwd)/hosts
    echo "Complete generate domains.txt"
  elif [[ $choosed == "hosts" ]]; then
    if [[ ! -f hosts.txt ]]; then
      get_data
    fi
    sed -i '/^#/d' dmerg.txt hmerg.txt
    sed -i '/^!/d' dmerg.txt hmerg.txt
    sed -i '/^$/d' dmerg.txt hmerg.txt
    sed -i 's/^*\./*/g' dmerg.txt hmerg.txt
    sed -i 's/^/0.0.0.0 /' dmerg.txt hmerg.txt
    sed -i 's/^127\.0\.0\.1/0.0.0.0/g' dmerg.txt hmerg.txt
    cat dmerg.txt hmerg.txt > merger_hosts.txt
    rm -f dmerg.txt hmerg.txt
    sort merger_hosts.txt > hosts.txt
    rm -f merger_hosts.txt
    rm -rf $(pwd)/domains $(pwd)/hosts
    echo "Complete generate hosts.txt file"
  fi
}

function action(){
  shopt -s nullglob
  if [[ ! -f domains.txt && -z $(ls ./data/user/*) ]]; then
    if [[ ! -f domains.txt ]]; then
      echo "Configure data..."
      sed -i '/^#/d' dmerg.txt hmerg.txt
      sed -i '/^!/d' dmerg.txt hmerg.txt
      sed -i '/^$/d' dmerg.txt hmerg.txt
      sed -i 's/^127\.0\.0\.1 /*./g' dmerg.txt hmerg.txt
      sed -i 's/^0\.0\.0\.0 /*./g' dmerg.txt hmerg.txt
      cat dmerg.txt hmerg.txt > merger_domains.txt
      rm -f dmerg.txt hmerg.txt
      sort merger_domains.txt > domains.txt
      rm -f merger_domains.txt
      rm -rf $(pwd)/domains $(pwd)/hosts
    fi
    cp ./data/example/* ./data/user/
    for file in ./data/user/example-*.txt; do mv "$file" "./data/user/${file#./data/user/example-}"; done
    if [[ -f custom-rules.txt ]]; then
      cat domains.txt custom-rules.txt >> $(pwd)/data/user/blacklist.txt
    else
      cat domains.txt >> $(pwd)/data/user/blacklist.txt
    fi
  elif [[ -f domains.txt && -z $(ls ./data/user/*) ]]; then
    cp ./data/example/* ./data/user/
    for file in ./data/user/example-*.txt; do mv "$file" "./data/user/${file#./data/user/example-}"; done
    if [[ -f custom-rules.txt ]]; then
      cat domains.txt custom-rules.txt >> $(pwd)/data/user/blacklist.txt
    else
      cat domains.txt >> $(pwd)/data/user/blacklist.txt
    fi
  fi
}

function run_dnscrypt(){
  _architecture=$(uname -m)
  if [[ -d /data/data/com.termux ]]; then
    system="android"
    if [[ _architecture == "aarch64" ]]; then
      _architecture="arm64"
    fi
  else
    if [[ -n $(uname -mrs | grep -w Microsoft | sed "s/.*\-//" | awk "{print $1}") ]]; then
      PS3="You can choose : "
      select opt in Windows Linux; do
        case $opt in
          Windows )  system="windows";;
          Linux   )  system="linux";;
          * )         echo "Your system not supported";
        esac
      done
    else
        system="linux"
    fi
  fi
  if [[ $system == "windows" ]]; then
    _mysystem=${system}${_architecture}
  else
    _mysystem=${system}_${_architecture}
  fi
  if [[ $system == "android" ]]; then
    _link="https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/2.1.4/dnscrypt-proxy-${_mysystem}-2.1.4.zip"
  else
    _link="https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/2.1.4/dnscrypt-proxy-${_mysystem}-2.1.4.tar.gz"
  fi
  if [[ ! -f ./data/dnscrypt/${system}-${_architecture}/dnscrypt-proxy.toml || ./data/dnscrypt/${system}-${_architecture}/dnscrypt-proxy || ./data/dnscrypt/${system}-${_architecture}/localhost.pem ]]; then
    if [[ $system == "android" ]]; then
      if ! which unzip >/dev/null &>1; then
        pkg install unzip &>/dev/null
      fi
      unzip dnscrypt-proxy-${_mysystem}-2.1.4.zip ${system}-${_architecture}/dnscrypt-proxy ${system}-${_architecture}/localhost.pem
      rm dnscrypt-proxy-${_mysystem}-2.1.4.zip
      mv ${system}-${_architecture} ./data/dnscrypt/
      cp ./data/dnscrypt/dnscrypt-proxy.toml ${system}-${_architecture}/
      sed -i "s/127.0.0.1:53/127.0.0.1:5453/" ./data/dnscrypt/${system}-${_architecture}/dnscrypt-proxy.toml
      sed -i "s/# forwarding_rules = 'forwarding-rules.txt'/forwarding_rules = 'forwarding-rules.txt'/" ./data/dnscrypt/${system}-${_architecture}/dnscrypt-proxy.toml
      sed -i "s/# cloaking_rules = 'cloaking-rules.txt'/cloaking_rules = 'cloaking-rules.txt'/" ./data/dnscrypt/${system}-${_architecture}/dnscrypt-proxy.toml
      sed -i "s/# map_file = 'example-captive-portals.txt'/map_file = 'captive-portals.txt'/" ./data/dnscrypt/${system}-${_architecture}/dnscrypt-proxy.toml
      sed -i "s/# blocked_names_file = 'blocked-names.txt'/blocked_names_file = 'blacklist.txt'/" ./data/dnscrypt/${system}-${_architecture}/dnscrypt-proxy.toml
      sed -i "s/# blocked_ips_file = 'blocked-ips.txt'/blocked_ips_file = 'ip-blacklist.txt'/" ./data/dnscrypt/${system}-${_architecture}/dnscrypt-proxy.toml
      sed -i "s/# allowed_names_file = 'allowed-names.txt'/allowed_names_file = 'whitelist.txt'/" ./data/dnscrypt/${system}-${_architecture}/dnscrypt-proxy.toml
      sed -i "s/# allowed_ips_file = 'allowed-ips.txt'/allowed_ips_file = 'ip-whitelist.txt'/" ./data/dnscrypt/${system}-${_architecture}/dnscrypt-proxy.toml
    elif [[ $system == "linux" ]]; then
      echo "Comming Soon"
    elif [[ $system == "windows" ]]; then
      echo "Comming Soon"
    fi
  fi
  exec ./data/dnscrypt/${system}-${_architecture}/dnscrypt-proxy &
}

function generate_opt(){
  PS3="What do you generated? "
  select opt in Domains Hosts; do
    case $opt in
      Domains ) choosed="domains"
            generate
            break;;
      Hosts ) choosed="hosts"
            generate
            break;;
      * ) echo "Follow instructions"
    esac
  done
}

if [[ -f "$config_file" ]]; then
  PS3="Choose action : "
  select opt in Generate Run; do
    case $opt in
      Generate )   generate_opt
                  break;;
      Run )  rules_file=$(grep -E '^rules_file\s*=' "$config_file" | awk -F '=' '{print $2}' | tr -d '[:space:]' | sed 's/"//g')
              if [[ "$rules_file" == "default" ]]; then
                # run_dnscrypt
              elif [[ "$rules_file" == "user" ]]; then
                action
                # run_dnscrypt
              fi
              break;;
      * ) echo "Follow instructions"
    esac
  done
else
  echo "Config file not found: $config_file"
fi