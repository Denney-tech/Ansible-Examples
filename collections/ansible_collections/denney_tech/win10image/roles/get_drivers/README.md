get_drivers
=========

Note: This role makes use of default values that fit my particular "windows_bridge" host for Ansible. Those vars can be overwritten, but they default to using an E: drive. In my case, I'm using a storage pool with Tier 1 and 2 NVME/SATA SSD caches and large HDD storage to help improve performance. We maintain a large number of models with MDT.

Requirements
------------
Windows host with Microsoft Deployment Toolkit installed in the default location.

Role Variables
--------------

Dependencies
------------

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      collections:
        - denney_tech.win10image
      roles:
         - { role: get_drivers }

License
-------

BSD

Author Information
------------------

Caleb Denney
