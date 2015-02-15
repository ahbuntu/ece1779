module Manager::WorkersHelper
  def worker_health(worker)
    @health[worker.instance.id][:state] rescue "-"
  end

  def worker_public_ip(worker)
    if worker.instance.public_ip_address
      link_to worker.instance.public_ip_address, "http://#{worker.instance.public_ip_address}", :target => "_blank"
    else
      nil
    end
  end

  def worker_public_dns(worker)
    if worker.instance.public_dns_name
      link_to worker.instance.public_dns_name, "http://#{worker.instance.public_dns_name}", :target => "_blank"
    else
      nil
    end
  end
end
