#!/bin/bash
set -e

echo "Renewing all kubernetes control plane certificates..."
kubeadm certs renew all
mv -f ~/.kube/config ~/.kube/_old_kube_config
cp -f /etc/kubernetes/admin.conf ~/.kube/config

echo "Waiting for kubernetes pods to be deleted..."
mkdir -p /tmp/k8s_manifests
mv /etc/kubernetes/manifests/*.yaml /tmp/k8s_manifests/
sleep 30
until ! kubectl get nodes > /dev/null 2>&1;
do
    sleep 1
done

echo "Waiting for kubernetes pods to restart..."
mv /tmp/k8s_manifests/*.yaml /etc/kubernetes/manifests/
sleep 30
until kubectl get nodes 2>&1 | grep -q " Ready ";
do
    sleep 1
done
rm -rf /tmp/k8s_manifests

echo "Renewing kubelet client certificate..."
mv -f /etc/kubernetes/kubelet.conf /etc/kubernetes/_old_kubelet.conf
rm -rf /var/lib/kubelet/pki/_old_kubelet-client
mkdir -p /var/lib/kubelet/pki/_old_kubelet-client
mv /var/lib/kubelet/pki/kubelet-client* /var/lib/kubelet/pki/_old_kubelet-client/
kubeadm kubeconfig user --config kubeadm_config.yaml --org system:nodes --client-name system:node:$NODE --v=9 > /etc/kubernetes/kubelet.conf
systemctl restart kubelet
until test -f "/var/lib/kubelet/pki/kubelet-client-current.pem";
do
    sleep 1
done
sed -i -e "/    client-certificate-data/s/.*/    client-certificate: \/var\/lib\/kubelet\/pki\/kubelet-client-current.pem/" /etc/kubernetes/kubelet.conf
sed -i -e "/    client-key-data/s/.*/    client-key: \/var\/lib\/kubelet\/pki\/kubelet-client-current.pem/" /etc/kubernetes/kubelet.conf
systemctl restart kubelet
until kubectl get nodes 2>&1 | grep -q " Ready ";
do
    sleep 1
done
echo "Node is ready..."

echo ""
echo "+ kubeadm certs check-expiration"
kubeadm certs check-expiration

echo ""
echo "+ openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates"
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates
