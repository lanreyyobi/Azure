cat << EOF >> ~/.ssh/config

Host ${user}
   HostName ${hostname}
   User ${user}
   IdentityFile ${identityfile}
EOF