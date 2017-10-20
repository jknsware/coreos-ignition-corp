# WARNING: DO NOT HTTP SERVE EVERYTHING IN THIS DIRECTORY

# Download Configuration Transpiler for Container Linux
https://github.com/coreos/container-linux-config-transpiler/releases
  wget https://github.com/coreos/container-linux-config-transpiler/releases/download/v0.5.0/ct-v0.5.0-x86_64-apple-darwin
  mv ct-v0.5.0-x86_64-apple-darwin ct
  chmod +x ct

# Generate Ignition configuraiton:
./ct < container_linux_config.yml > ignition.json

# Generate password hash
openssl passwd -1 -salt xyz MY_PASSWORD

