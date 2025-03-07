locals {
  s3_resources = {
    # type = map(object({
    #   bucket = string
    #   path   = string
    # }))
    for name, res in {
      etcd = {
        bucket = "randomcoww-etcd-2"
        path   = "snapshot"
      }
      documents = {
        bucket = "randomcoww-documents"
        path   = ""
      }
      pictures = {
        bucket = "randomcoww-pictures"
        path   = ""
      }
      music = {
        bucket = "randomcoww-music"
        path   = ""
      }
    } :
    name => merge(res, {
      resource = join("/", concat([res.bucket], compact(split("/", res.path))))
    })
  }
}