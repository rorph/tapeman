<?php

// (c) z3n - R1V1@161104 - www.overflow.biz - rodrigo.orph@gmail.com

if (!defined('MODE'))
	define('MODE', PHP_SAPI == 'cli' ? 'CLI' : 'FRONTEND');

define('__ROOT__', dirname(__DIR__) . '/');
mb_internal_encoding('UTF-8');

// base
switch (MODE) {
	default: // frontend / others
		set_time_limit(120);
		ini_set('memory_limit', '536870912');
}

require_once(__ROOT__ . 'include/Debug.php');
require_once(__ROOT__ . 'include/config.php');
require_once(__ROOT__ . 'include/common.php');

spl_autoload_register('cv_autoload');
# ini_set('session.cookie_domain', $config['session']['cookie_domain']);

define('DEV_ENV', CONFIG::$config['DEV_ENV']);

if ($config['DEV_ENV']) { // dev
	error_reporting(E_ALL);
} else { // production
	error_reporting(E_ALL ^ (E_DEPRECATED | E_NOTICE | E_STRICT));
}

# dump errors on page will break shit
# ini_set('display_errors', 'on');

// special post loaders
switch (MODE) {
	case 'CLI':
	case 'API':
		switch (CONFIG::$config['db']['type']) {
			case 'sqlite':
				DB::init(
					'sqlite:' . __ROOT__ . CONFIG::$config['db']['path'],
					null,
					null,
					array(
						PDO::ATTR_PERSISTENT => false,
						PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
						PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
					)
				);
				break;
			
			case 'postgres':
				DB::init(
					'pgsql:dbname=' . CONFIG::$config['postgres']['database'] . ';host=' . CONFIG::$config['postgres']['host'],
					CONFIG::$config['postgres']['user'],
					CONFIG::$config['postgres']['password'],
					array(
						PDO::ATTR_PERSISTENT => false,
						PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
						PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
					)
				);
				break;
			
			default:
				die("\n*** Unsupported db type: " . CONFIG::$config['db']['type'] . " aborting\n");
		}
		break;
}
