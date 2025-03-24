disable_mlock = true

listener "tcp"{
  address = "0.0.0.0:9200"
  purpose = "api"
  tls_disable   = true
}

listener "tcp"{
  address = "0.0.0.0:9201"
  purpose = "cluster"
}

listener "tcp"{
  address = "0.0.0.0:9203"
  purpose = "ops"
  tls_disable   = true
}

controller {
  name = "boundary-controller"
  description = "Boundary controller"
  public_cluster_addr = "boundary-cluster.apps.67e0a8e5a503e6e92a9ea91b.ocp.techzone.ibm.com:443"
  license = "file:////etc/boundary/license/license.hclic"
  graceful_shutdown_wait_duration = "10s"
  database {
      url = "env://POSTGRESQL_CONNECTION_STRING"
  }
}

kms "aead"{
  purpose = "root"
  aead_type = "aes-gcm"
  key = "8fZBjCUfN0TzjEGLQldGY4+iE9AkOvCfjh7+p0GtRBQ="
  key_id = "global_root"
}

kms "aead"{
  purpose = "worker-auth"
  aead_type = "aes-gcm"
  key = "8fZBjCUfN0TzjEGLQldGY4+iE9AkOvCfjh7+p0GtRBQ="
  key_id = "global_worker-auth"
}

kms "aead" {
  purpose = "bsr"
  aead_type = "aes-gcm"
  key = "8fZBjCUfN0TzjEGLQldGY4+iE9AkOvCfjh7+p0GtRBQ="
  key_id = "bsr"
}
