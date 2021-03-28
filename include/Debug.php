<?php

// (c) z3n - R1V1@170830 - www.overflow.biz - rodrigo.orph@gmail.com

abstract class DEBUG {
	public static $debug = false;
	public static $query = false;
	public static $log_to_file = false;
	public static $log_colors = true;
	public static $pid = false;
	public static $start = false;
	public static $logLevel = 6;
	
	private static $fd = false;
	private static $colors = array(
		"off"        => "\033[0m",
		"bold"       => "\033[1m",
		"italic"     => "\033[3m",
		"underline"  => "\033[4m",
		"blink"      => "\033[5m",
		"inverse"    => "\033[7m",
		"hidden"     => "\033[8m",
		"black"      => "\033[30m",
		"red"        => "\033[31m",
		"red_b"      => "\033[31;1m",
		"green"      => "\033[32m",
		"green_b"    => "\033[32;1m",
		"yellow"     => "\033[33m",
		"yellow_b"   => "\033[33;1m",
		"blue"       => "\033[34m",
		"blue_b"     => "\033[34;1m",
		"magenta"    => "\033[35m",
		"magenta_b"  => "\033[35;1m",
		"cyan"       => "\033[36m",
		"cyan_b"     => "\033[36;1m",
		"white"      => "\033[37m",
		"white_b"    => "\033[37;1m",
		"black_bg"   => "\033[40m",
		"red_bg"     => "\033[41m",
		"green_bg"   => "\033[42m",
		"yellow_bg"  => "\033[43m",
		"blue_bg"    => "\033[44m",
		"magenta_bg" => "\033[45m",
		"cyan_bg"    => "\033[46m",
		"white_bg"   => "\033[47m"
	);
	
	private static function resolvePriority($level) {
		switch (strtolower($level)) {
			case 'fatal':
				return 2; # LOG_CRIT
			case 'error':
				return 3; # LOG_ERR
			case 'warn':
			case 'warning':
				return 4; # LOG_WARNING
			case 'info':
				return 6; # LOG_INFO
			case 'notice':
				return 5; # LOG_NOTICE
			case 'trace':
			case 'debug':
				return 7; # LOG_DEBUG
			default:
				return 1; # Unknown
		}
	}
	
	private static function output($level, $trace, $params) {
		if (self::resolvePriority($level) > self::$logLevel)
			return;
		if (self::$pid === false)
			self::$pid = getmypid();
		$msg = array();
		
		if ($trace !== false && is_array($trace) && !empty($trace)) {
			$_trace = array();
			if (self::$log_colors) {
				if (isset($trace[0]['file']))
					$_trace[] = self::$colors['green'] . basename($trace[0]['file']) . self::$colors['white'] . '@' . $trace[0]['line'];
				if (isset($trace[1])) {
					if (isset($trace[1]['class']))
						$_trace[] = self::$colors['yellow'] . $trace[1]['class'] . self::$colors['green'] . $trace[1]['type'] . self::$colors['cyan'] . $trace[1]['function'];
					elseif (isset($trace[1]['function']))
						$_trace[] = self::$colors['cyan'] . $trace[1]['function'];
				}
				
				$trace = (empty($_trace) ? self::$colors['red_b'] . '<Unknown>' : implode(self::$colors['off'] . ' ', $_trace)) . self::$colors['off'];
			} else {
				if (isset($trace[0]['file']))
					$_trace[] = basename($trace[0]['file']);
				if (isset($trace[0]['line']))
					$_trace[] = '@' . $trace[0]['line'];
				if (isset($trace[1])) {
					if (isset($trace[1]['class']))
						$_trace[] = $trace[1]['class'];
					if (isset($trace[1]['type']))
						$_trace[] = $trace[1]['type'];
					if (isset($trace[1]['function']))
						$_trace[] = $trace[1]['function'];
				}
				
				$trace = empty($_trace) ? '<Unknown>' : implode(' ', $_trace);
			}
		} else {
			$trace = self::$log_colors ? self::$colors['red_b'] . '<Unknown>' . self::$colors['off'] : '<Unknown>';
		}
		
		foreach ($params as $param)
			$msg[] = is_array($param) ?
				'`' . print_r($param, true) . '`'
			:
				(
					is_object($param) ?
						'`' . serialize($param) . '`'
					:
						$param
				);
		
		try {
			$msg = self::$log_colors ?
					self::$colors['white_b'] . date('Y-m-d H:i:s') . self::$colors['off'] . self::$colors['blue_b'] . ' [' . $level . ']' . self::$colors['off'] . self::$colors['magenta'] . ' [' . MODE . ':' . self::$pid . '] ' . self::$colors['off'] .
					$trace . (isset($_SERVER['REMOTE_ADDR']) ? ' ' . self::$colors['bold'] . self::$colors['white'] . $_SERVER['REMOTE_ADDR'] . self::$colors['off'] : '') . ' > ' .
					self::$colors['bold'] . self::$colors['white_b'] . implode(' ', $msg) . self::$colors['off'] . "\n"
				:
					date('Y-m-d H:i:s') . ' [' . $level . '] [' . MODE . ':' . self::$pid . '] ' .
					$trace . (isset($_SERVER['REMOTE_ADDR']) ? ' ' . $_SERVER['REMOTE_ADDR'] : '') . ' > ' .
					implode(' ', $msg) . "\n";
		} catch (Exception $e) {
			return;
		}
		
		/*
		if (__PKG)
			error_log($msg);
			# file_put_contents("php://stderr", $msg, FILE_APPEND);
			# syslog(LOG_ERR, $msg);
			# @fwrite(self::$fd, $msg);
		elseif (self::$log_to_file !== false)
			file_put_contents(self::$log_to_file, $msg, FILE_APPEND);
		else
			echo $msg;
		*/
		
		if (self::$log_to_file !== false)
			file_put_contents(self::$log_to_file, $msg, FILE_APPEND);
		else
			echo $msg;
	}
	
	public static function init() {
		if (!self::$debug)
			return;
		if (isset(CONFIG::$config['logLevel']))
			self::$logLevel = self::resolvePriority(CONFIG::$config['logLevel']);
		if (self::$log_to_file === false)
			self::$log_colors = false;
		elseif (isset(CONFIG::$config['log_colors']))
			self::$log_colors = CONFIG::$config['log_colors'];
		
		self::$start = microtime(true);
		$params = array(self::$start);
		
		if (isset($_SERVER) && isset($_SERVER['REQUEST_METHOD']))
			$params = array($_SERVER['REQUEST_METHOD'], $_SERVER['REQUEST_URI']);
		/*
		if (__PKG)
			self::$fd = @fopen('php://stdout', 'w');
		*/
		self::output('INIT', false, $params);
		
		register_shutdown_function(__CLASS__ . '::close');
	}
	
	public static function close() {
		DB::checkErrors(true);
		if (!empty(DB::$errors))
			self::output('WARN', false, array('DB Errors happened:', DB::$errors));
		
		self::output('SHUTDOWN', false, array('Time: ' . (microtime(true) - self::$start) . 's'));
		/*
		if (__PKG)
			@fclose(self::$fd);
		*/
	}
	
	public static function __callStatic($name, $params) {
		if (!self::$debug)
			return;
		
		$trace = debug_backtrace(DEBUG_BACKTRACE_PROVIDE_OBJECT | DEBUG_BACKTRACE_IGNORE_ARGS, 2);
		
		self::output(strtoupper($name), $trace, $params);
	}
}
