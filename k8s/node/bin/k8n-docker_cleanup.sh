#!/usr/bin/env bash
exec 1> >(logger -s -t $(basename $0)) 2>&1
# · ---
VERSION=1.0
# · ---
docker system prune -f;
# · ---
#docker stop $(docker ps -qa) && sleep 1;
#
#docker rm -f $(docker ps -qa) && sleep .1 && docker rmi -f $(docker images -q) && \
#sleep .1 && docker volume rm $(docker volume ls -q);
#
#for mount in $(mount | grep tmpfs | grep '/var/lib/kubelet' | awk '{ print $3 }') \
#  /var/lib/kubelet; do
#    umount $mount;
#done
#
#sleep .5;
#
#rm -rf /etc/ceph /etc/cni /etc/kubernetes /opt/cni /opt/rke \
#  /run/secrets/kubernetes.io /run/calico /run/flannel /var/lib/calico /var/lib/etcd \
#  /var/lib/cni /var/lib/kubelet /var/lib/rancher/rke/log /var/log/containers \
#  /var/log/kube-audit /var/log/pods /var/run/calico;
#
#sleep .5;
#
#/etc/init.d/docker restart;

exit 0
