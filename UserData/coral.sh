# Save build parameters
echo "Build Parameters:" >> /root/build-params.txt
echo "DatabaseRootUser: ${DATABASE_ROOT_USER}" >> /root/build-params.txt
echo "DatabaseRootPass: ${DATABASE_ROOT_PASS}" >> /root/build-params.txt
echo "CoralDatabaseUser: ${CORAL_DATABASE_USER}" >> /root/build-params.txt
echo "CoralDatabasePass: ${CORAL_DATABASE_PASS}" >> /root/build-params.txt
echo "CoralAdminUser: ${CORAL_ADMIN_USER}" >> /root/build-params.txt
echo "CoralAdminPass: ${CORAL_ADMIN_PASS}" >> /root/build-params.txt
echo "CoralAdminEmail: ${CORAL_ADMIN_EMAIL}" >> /root/build-params.txt
echo "CoralSiteName: ${CORAL_SITE_NAME}" >> /root/build-params.txt
echo "CustomShScriptUrl: ${CUSTOM_SH_SCRIPT_URL}" >> /root/build-params.txt

# Mount external devices 
mkfs -t ext4 /dev/xvdb
mkfs -t ext4 /dev/xvdc
cp -pr /var /tmp
cp -pr /home /tmp 
mount /dev/xvdb /var
mount /dev/xvdc /home
cp -pr /etc/fstab /etc/fstab.orig
echo "/dev/xvdb   /var        ext4    defaults,nofail 0   2" >> /etc/fstab
echo "/dev/xvdc   /home       ext4    defaults,nofail 0   2" >> /etc/fstab
mount -a
cp -prT /tmp/var /var
cp -prT /tmp/home /home
rm -rf /tmp/var
rm -rf /tmp/home

# Set timezone
rm -f /etc/localtime
ln -s /usr/share/zoneinfo/US/Eastern /etc/localtime

# Run updates
yum -y update > /root/updates.txt

# Install Apache
yum -y install httpd24 > /root/install-log.txt 2>&1
service httpd start >> /root/install-log.txt 2>&1
chkconfig httpd on >> /root/install-log.txt 2>&1

# Install mysql
yum -y install mysql-server >> /root/install-log.txt 2>&1
chkconfig mysqld on >> /root/install-log.txt 2>&1
service mysqld start >> /root/install-log.txt 2>&1
mysql -e "UPDATE mysql.user SET Password = PASSWORD('${DATABASE_ROOT_PASS}') WHERE User = 'root'" >> /root/install-log.txt 2>&1
mysql -e "DROP USER ''@'localhost'" >> /root/install-log.txt 2>&1
mysql -e "DROP USER ''@'$(hostname)'" >> /root/install-log.txt 2>&1
mysql -e "DROP DATABASE test" >> /root/install-log.txt 2>&1
mysql -e "FLUSH PRIVILEGES" >> /root/install-log.txt 2>&1

# Install php
 yum -y install php56 >> /root/install-log.txt 2>&1
 yum -y install php56-mysqlnd >> /root/install-log.txt 2>&1
 yum -y install php56-mbstring >> /root/install-log.txt 2>&1
 service httpd restart >> /root/install-log.txt 2>&1

 #Install git
 yum -y install git

 #Clone Coral
 cd /var/www
 git clone https://github.com/coral-erm/coral.git
 mv coral html
 cd html
 chmod -R apache:apache *

# Create sshusers group
groupadd -g 505 sshusers
usermod -a -G sshusers ec2-user
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
echo "" >> /etc/ssh/sshd_config
echo "# Make an allowance for sshusers; C. Birmingham II" >> /etc/ssh/sshd_config
echo "AllowGroups sshusers" >> /etc/ssh/sshd_config
sed -i 's/PermitRootLogin forced-commands-only/#PermitRootLogin forced-commands-only/g' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
/etc/init.d/sshd restart

# Install AWS agent
mkdir -p /stage
cd /stage
wget https://d1wk0tztpsntt1.cloudfront.net/linux/latest/install
bash install
cd

# Install ClamAV antivirus
yum -y install clamav clamd clamav-update
groupadd -g 510 clamav
useradd -u 510 -g clamav -s /bin/false -c "Clam AntiVirus" clamav
mkdir -p /data/quarantine
cp /usr/share/doc/clamav-server-*/clamd.conf /etc/
cp /etc/freshclam.conf /etc/freshclam.conf.orig
awk '/Example/{c++;if(c==2){sub("Example","# Example");c=0}}1' /etc/freshclam.conf > /etc/freshclam.conf.tmp
mv -f /etc/freshclam.conf.tmp /etc/freshclam.conf
sed -i 's/#DatabaseDirectory/DatabaseDirectory/g' /etc/freshclam.conf
cp /etc/clamd.conf /etc/clamd.conf.orig
awk '/Example/{c++;if(c==2){sub("Example","# Example");c=0}}1' /etc/clamd.conf > /etc/clamd.conf.tmp
mv -f /etc/clamd.conf.tmp /etc/clamd.conf
sed -i 's/#DatabaseDirectory/DatabaseDirectory/g' /etc/clamd.conf
cp /etc/sysconfig/freshclam /etc/sysconfig/freshclam.orig
sed -i 's/FRESHCLAM_DELAY=disabled-warn/# FRESHCLAM_DELAY=disabled-warn/g' /etc/sysconfig/freshclam

# Set up SELinux, changing from enforcing to permissive
yum -y install selinux-policy selinux-policy-targeted policy policycoreutils-python setools tree
cp -pr /etc/sysconfig/selinux /etc/sysconfig/selinux.orig
cp -pr /etc/selinux/config /etc/selinux/config.orig
cp -pr /boot/grub/menu.lst /boot/grub/menu.lst.orig 
sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux
sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
sed -i 's/selinux=0/selinux=1 security=selinux/g' /boot/grub/menu.lst
touch /.autorelabel
sync
