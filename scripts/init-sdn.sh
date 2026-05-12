#!/bin/bash
# Script d'initialisation SDN - Projet OVS + Ryu + VXLAN

echo "=== Initialisation du projet SDN ==="

# 1. Nettoyer les anciens ports OVS cassés
echo "[1] Nettoyage OVS..."
sudo ovs-vsctl del-br br-int 2>/dev/null || true
sudo ovs-vsctl del-br br-vxlan 2>/dev/null || true

# 2. Créer les bridges
echo "[2] Création des bridges..."
sudo ovs-vsctl add-br br-int
sudo ovs-vsctl add-br br-vxlan

# 3. Connecter OVS à Ryu
echo "[3] Connexion OVS -> Ryu..."
sudo ovs-vsctl set-controller br-int tcp:127.0.0.1:6653

# 4. Attacher les conteneurs
echo "[4] Attachement des conteneurs..."
sudo ovs-docker add-port br-int eth0 host1
sudo ovs-docker add-port br-int eth0 host2

# 5. Configurer VXLAN
echo "[5] Configuration VXLAN..."
sudo ovs-vsctl add-port br-vxlan vxlan0 \
  -- set interface vxlan0 type=vxlan options:remote_ip=flow
sudo ovs-docker add-port br-vxlan eth1 host1
sudo ovs-docker add-port br-vxlan eth1 host2

echo "=== Terminé ! ==="
sudo ovs-vsctl show
