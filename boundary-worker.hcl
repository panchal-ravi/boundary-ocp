disable_mlock = true

listener "tcp" {
  address = "0.0.0.0:9202"
  purpose = "proxy"
}
        
worker {
  public_addr = "worker.apps.67e0a8e5a503e6e92a9ea91b.ocp.techzone.ibm.com:443"
  auth_storage_path = "/etc/boundary/auth-storage"
  tags {
    key = ["ingress", "worker1"]
  }
  initial_upstreams = ["boundary-cluster.apps.67e0a8e5a503e6e92a9ea91b.ocp.techzone.ibm.com:443"]
}