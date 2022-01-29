Role Name
=========

This is a dynamic role intended to provision a remote host from a basic default configuration to an Ansible ready configuration for any connection type or operating system.
(Presently, only Windows is supported! :pikachu-shocked-face:)

One of the main ideas of this role is to cache whether or not the remote host has been setup for Ansible connections, and skip the entire role when true. This allows all other roles to mark this role as a dependency, allowing Ansible to handle first time connections to hosts on the fly with any other role.

Requirements
------------


Role Variables
--------------

bootstrap.enabled: has the connection plugin type been setup to meet this role's requirements? Skips related tasks when true
bootstrap.configured: has the OS specific requirements of this role been met? Skips related tasks when true
bootstrap.force_update: When defined (any value), runs all tasks that might otherwise be skipped.

psrp.windows_bridge: When true, leaves the PSSessionConfiguration "Ansible.AWX.Automation" enabled for Second Hop scenerios to run on a designated host. This should be a statically defined windows_bridge alias of a desired Windows delegate.

Dependencies
------------

None.

Example Playbook
----------------

    - hosts: servers
      roles:
         - role: bootstrap
           bootstrap:
             force_update: true

License
-------

BSD

Author Information
------------------

@Denney-tech
