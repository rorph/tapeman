<?php

if (MODE == 'CLI')
	DEBUG::$debug = true;

$config = __ROOT__ . 'include/config.json';

if (!file_exists($config))
	die('FATAL: Config is missing! Expected path: `' . $config . '`');

$config = json_decode(file_get_contents($config), true);

if ($config['debug_to_file'] !== false) {
	DEBUG::$debug = true;
	DEBUG::$log_to_file = $config['debug_to_file'];
}

DEBUG::init();

if ($config['DEV_ENV']) {
	error_reporting(E_ALL);
	// ini_set('display_errors', true);
	ini_set('display_errors', false);
} else {
	error_reporting(E_ALL);
	ini_set('display_errors', false);
}

if (empty($config) || $config === false)
	die('FATAL: Invalid config');

abstract class CONFIG {
	public static $config;
}

CONFIG::$config = &$config;
