<?php

// (c) z3n - R1V1@201226 - www.overflow.biz - rodrigo.orph@gmail.com

$path = explode('/', parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH));
$curPage = empty($path[1]) ? 'index' : $path[1];

define('MODE', 'API');

require_once('include/init.php');

if (isset($_GET['debug']) && $_GET['debug'] == $config['debug_key'])
	DEBUG::$debug = $_debug = true;
else
	$_debug = DEBUG::$debug;

# DEBUG::$debug = $_debug = true;

DEBUG::$log_colors = false;
DEBUG::init();

/*
error_reporting(E_ALL);
ini_set('display_errors', 'on');
*/

if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
	pre_flight();
	exit;
}

$fields = array('rootID', 'name', 'path', 'fieldType', 'valueType', 'valueDefault', 'extra', 'mandatory', 'isDynamic', 'reflectionName');

switch ($curPage) {
	case 'query':
		if (empty($_POST['q']))
			json_error('No query provided');
		
		$s = DB::prepare($_POST['q']);
		$s->execute();
		$r = $s->fetchAll();

		if (isset($_GET['json'])) // json object output
			_r_json($r);
		else { // sqlite3 output
			foreach ($r as $e) {
				$keys = array_keys($e);
				$line = [];
				foreach ($keys as $k) {
					$line[] = $e[$k];
				}

				print_r(implode($line, '|'));
			}
		}
		
		DB::close();
		break;
	case 'replace':
		if (empty($_FILES['db']))
			json_error('No files uploaded');
		
		$fn = __ROOT__ . 'db/' . md5(microtime(true) . $_FILES['db']['name']) . '.db';
		if (!move_uploaded_file($_FILES['db']['tmp_name'], $fn))
			json_error('Error moving uploaded file!');
		DB::close();
		copy($fn, __ROOT__ . CONFIG::$config['db']['path']);
		unlink($fn);
		_r_json(array('r' => 1));
		break;
	case 'download':
		$local_file = __ROOT__ . CONFIG::$config['db']['path'];
		if (file_exists($local_file) && is_file($local_file)) {
			header('Cache-control: private');
			header('Last-Modified: ' . gmdate('D, d M Y H:i:s', filemtime($local_file)).' GMT', true);
			header('Content-Type: application/octet-stream');
			header('Content-Length: '.filesize($local_file));
			header('Content-Disposition: filename=' . CONFIG::$config['db']['path']);
			
			flush();
			$file = fopen($local_file, "r");
			
			while(!feof($file))
			{
					print fread($file, 1024);
					flush();
			}
			fclose($file);
			exit;
		} else {
			die('Error: The file '.$local_file.' does not exist!');
		}
		break;
}

// 404
header('HTTP/1.0 404 Not found');
header('Location: /');

exit;
