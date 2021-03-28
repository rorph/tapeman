<?php

// (c) z3n - R1V1@161104 - www.overflow.biz - rodrigo.orph@gmail.com

function cv_autoload($class) {
	$fileName = __ROOT__ . 'include/' . $class . '.php';
	if (file_exists($fileName)) {
		require_once($fileName);
	}
}

function add_cors_header() {
	$ref = false;
	
	if (isset($_SERVER['HTTP_ORIGIN']) && !empty($_SERVER['HTTP_ORIGIN']))
		$ref = $_SERVER['HTTP_ORIGIN'];
	if (!$ref && isset($_SERVER['HTTP_REFERER']))
		$ref = implode('/', array_slice(explode('/', $_SERVER['HTTP_REFERER']), 0, 3));
	
	if ($ref !== false) {
		if (in_array($ref, CONFIG::$config['arc']['cors']['Access-Control-Allow-Origin'])) {
			@ header('Access-Control-Allow-Origin: '.$ref);
			@ header('Access-Control-Allow-Methods: '.CONFIG::$config['arc']['cors']['Access-Control-Allow-Methods']);
			@ header('Access-Control-Allow-Headers: '.CONFIG::$config['arc']['cors']['Access-Control-Allow-Headers']);
			@ header('Access-Control-Allow-Credentials: true');
			
			return true;
		} else {
			@ header('Access-Control-Allow-Origin: not.allowed');
			
			return false;
		}
	}
	
	// no headers added, but also no headers asked
	return true;
}


function pre_flight() {
	http_response_code(204); // no content
	
	// avoid caching not allowed requests
	// if (add_cors_header())
		header('Access-Control-Max-Age: ' . CONFIG::$config['pre_flight_expiry']);
	
	header('Content-Type: text/plain');
	header('Content-Length: 0');
}

function json_error($msg, $fatal = true, $HTTPCode = 500) {
	http_response_code($HTTPCode);
	add_cors_header();
	
	@ header('Content-Type: application/json');
	@ header('Cache-Control: no-cache');
	
	echo json_encode(array('error' => $msg));

	if ($fatal)
		exit;
}


function _r_json($var, $dummy = false) {
	add_cors_header();
	
	header('Content-Type: application/json');
	header('Cache-Control: no-cache');
	
	if ($dummy) {
		ignore_user_abort(true);
		header('Connection: close');
		
		if (!empty($var)) {
			$res = json_encode($var);
			header('Content-Length: ' . strlen($res));
			echo $res;
		}
		
		flush();
	} else {
		echo is_array($var) ? json_encode($var) : $var;
	}
}
