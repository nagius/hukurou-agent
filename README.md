Hukurou Agent
=============

This software is the Agent daemon for the Hukurou monitoring system.

Goal
----

This program, meant to be run as a daemon on each node you want to monitor, will execute periodically Nagios's style commands (checks) and send the result to the Hukurou Core.

Configuration
-------------

The configuration is (by default) in the file ```/etc/hukurou/agent/config.yml```. The only key is ```:url``` which define the Core API's URL.

All check definition must be specified in the Hukurou Core configuration. The scripts must be present and executable on the node itself.

Usage
-----

Run ```bin/hukurou-agent```.
It will automatically get checks definition from Hukurou Core.

To reload the configuration from the Core API, send the HUP signal.


NOTE: Work in progress, not ready for production.
