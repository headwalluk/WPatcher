# Change log

All notable changes to this project will be documented in this file.


## [Unreleased]

...

## [1.2.0] - 2024-11-13

More robust checking for plugins that have already been patched, by slightly
loosening the grep for "// START : wpatcher" in a PHP file.

Added some new patches:

 * woocommerce 9.4.1
 * broken-link-checker 2.4.1
 * multiple-packages-for-woocommerce 1.1.1

## [1.0.0] - 2024-09-29

Initial release, with the following commands working:

patch, unpatch, backup, update

