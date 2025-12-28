[monitoring]
${monitoring_ip} ansible_user=ubuntu ansible_python_interpreter=/usr/bin/python3

[monitoring:vars]
environment=${environment}
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
