datacenter          = "DC1"
server              = true
bootstrap_expect    = 3
leave_on_terminate  = true
advertise_addr      = "192.168.0.100"
data_dir            = "/opt/consul/data"
client_addr         = "0.0.0.0"
log_level           = "INFO"
ui                  = true

# AWS cloud join
#retry_join          = ["provider=aws tag_key=Environment-Name tag_value=${environment_name}"]
#retry_join_wan      = [ ${wan_join} ]
# manual IP config join
#retry_join          = ["192.168.0.101,192.168.0.102"]
#retry_join_wan      = ["192.168.10.100"]

disable_remote_exec = false

connect {
  enabled = true
}

primary_datacenter = "DC1"

acl {
  enabled        = true
  default_policy = "deny"
  down_policy    = "extend-cache"
}
