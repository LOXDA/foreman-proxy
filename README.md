ansible-role-foreman-proxy
=========

Ansible role to deploy foreman smart_proxy (theforeman.org)

Requirements
------------

It is designed to be include as a submodule to a project with its siblings :

* `ansible-role-foreman-db`
* `ansible-role-foreman-puppet`
* `ansible-role-foreman-proxy` (this one)
* `ansible-role-foreman-app`
* `ansible-role-foreman-custom`

`ansible-role-mirror` should help you get started with mirroring needed repositories.

Role Variables
--------------

The role needs some vars (default/main.yml)
The vars are self-explanatory, to look for answer one could use : foreman-installer --help
All vars are combined in `tasks/Setup_Options.yml` ( -vv is your friend )

Example Playbook
----------------

```
- hosts: tfm_proxy
  gather_facts: true
  vars:
    oauth_consumer_key: "{{ hostvars[groups['tfm_app'][0]]['oauth_consumer_key'] }}"
    oauth_consumer_secret: "{{ hostvars[groups['tfm_app'][0]]['oauth_consumer_secret'] }}"
  roles:
    - role: foreman-proxy
    - role: ansible-role-deploy-git-repos
```

#### to deploy some ansible roles `on` the smart_proxy to run them `from` smart_proxy using remote_executions (foreman plugins ansible)
```
- hosts: tfm_proxy
  gather_facts: true
  roles:
    - role: ansible-role-deploy-git-repos
```

#### There is an omapi bug after isc-dhcp-server_4.4.1-2+deb10u1 (Debian 10 Buster), this help : 
```
--tags tfm,fixdhcp
- hosts: tfm_proxy
  gather_facts: true
  tasks:
    - name: fix isc-dhcp-server omapi bug with debian >10
      block:
      - name: Download libisc-export1100 package from Buster
        ansible.builtin.apt:
          deb: http://mirror.lab.loxda.net/debian-security/pool/updates/main/b/bind9/libisc-export1100_9.11.5.P4+dfsg-5.1+deb10u8_amd64.deb
      - name: Download libdns-export1104 package from Buster
        ansible.builtin.apt:
          deb: http://mirror.lab.loxda.net/debian-security/pool/updates/main/b/bind9/libdns-export1104_9.11.5.P4+dfsg-5.1+deb10u8_amd64.deb
      - name: Download isc-dhcp-server package from Buster
        get_url:
          url: http://mirror.lab.loxda.net/debian/pool/main/i/isc-dhcp/isc-dhcp-server_4.4.1-2+deb10u1_amd64.deb
          dest: /tmp/isc-dhcp-server_4.4.1-2+deb10u1_amd64.deb
      - name: Fix isc-dhcp-server version
        command: dpkg --force-downgrade --force-hold -i /tmp/isc-dhcp-server_4.4.1-2+deb10u1_amd64.deb
      - name: Hold isc-dhcp-server
        dpkg_selections: name=isc-dhcp-server selection=hold
      - name: Restart service isc-dhcp-server
        service: name=isc-dhcp-server state=restarted
      when: ansible_distribution == 'Debian' and "ansible_distribution_version" >= "10"
```      

License
-------

CC-BY-4.0

Author Information
------------------

Thomas Basset -- hobbyist sysadm <tomm+code@loxda.net>
