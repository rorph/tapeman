<?php

// (c) z3n - R1V1.1@161208 - www.overflow.biz - rodrigo.orph@gmail.com

// a simple PDOSingeton wrapper
// @requires php 5.3+

abstract class DB extends PDOSingleton {
	public static $db = false;
	public static $errors = [];
	
	public static function init($dsn, $username = false, $password = false, $driver_options = false) {
		DEBUG::debug("Init");
		
		if (self::$db !== false) {
			DEBUG::debug('Resetting existing connection');
			self::$db->close();
			self::$db = false;
		}
		
        //DEBUG::debug('Initializing DSN: ' . $dsn);
        self::$debug = DEBUG::$query;
        self::$db = new parent($dsn, $username, $password, $driver_options);
	}
	
	public static function __callStatic($name, $arg) {
		return self::$db->$name($arg);
	}
	
	public static function simpleKV($params, $table, $mode, $id = 'id') {
		$keys = array_keys($params);
		switch ($mode) {
			case 'insert':
				return array(
					'query' => 'INSERT INTO ' . $table . ' (' . implode(',', $keys) . ') VALUES (' . substr(str_repeat('?,', count($keys)), 0, -1) . ') RETURNING ' . $id,
					'values' => array_values($params)
				);
				break;
			
			case 'update':
				$query = 'UPDATE ' . $table . ' SET ';
				$values = array();
				foreach ($keys as $key) {
					if ($key != $id) {
						$query .= $key . ' = ?, ';
						$values[] = is_bool($params[$key]) ? ($params[$key] === true ? '1' : '0') : $params[$key];
					}
				}
				
				$values[] = $params[$id];
				
				return array(
					'query' => substr($query, 0, -2) . ' WHERE ' . $id . ' = ?',
					'values' => $values
				);
				break;
			
			case 'select':
				$query = 'SELECT * FROM ' . $table . '    ';
				$values = [];
				if($params){
					foreach ($keys as $key) {
						if ($key != $id) {
							if (strpos($query, ' WHERE ') === false)
								$query .= ' WHERE ';
							
							if (is_array($params[$key])) {
								$value = array_unique($params[$key]);
								$query .= $key . ' IN(' . implode(',', array_fill(0, count($value), '?')) . ') AND ';
								$values = array_merge($values, $value);
							} else {
								$query .= $key . ' = ? AND ';
								$values[] = is_bool($params[$key]) ? ($params[$key] === true ? '1' : '0') : $params[$key];
							}
						}
					}
				}
				return array(
					'query' => substr($query, 0, -4),
					'values' => $values
				);
				break;
			
			case 'delete':
				$query = 'DELETE FROM ' . $table . '    ';
				$values = [];
				if($params){
					foreach ($keys as $key) {
						if (strpos($query, ' WHERE ') === false)
							$query .= ' WHERE ';
						
						if (is_array($params[$key])) {
							$value = array_unique($params[$key]);
							$query .= $key . ' IN(' . implode(',', array_fill(0, count($value), '?')) . ') AND ';
							$values = array_merge($values, $value);
						} else {
							$query .= $key . ' = ? AND ';
							$values[] = is_bool($params[$key]) ? ($params[$key] === true ? '1' : '0') : $params[$key];
						}
					}
				}
				return array(
					'query' => substr($query, 0, -4),
					'values' => $values
				);
				break;
			
			default:
				throw new Exception('Undefined mode:' . $mode);
		}
	}
	
	public static function simplePQ($params, $returnS = false ) {
		$s = self::$db->prepare($params['query']);
		$result = $s->execute(isset($params['values']) ? $params['values']: array());
		
		if (DEBUG::$debug) {
			$params['query'] = self::$db->commentQuery($params['query']);
			DEBUG::debug('DB::simplePQ params:', $params);
		}
		
		if ($result === false) {
			self::$errors[] = $s->errorInfo();
			DEBUG::debug('DB::simplePQ error:', $s->errorInfo());
			
			return false;
		}
		//return the query object itself to be able to fetch (like fetching the ID after insert)
		return $returnS ? $s : $result;
	}
	
	/**
	 * Sets an arbitrary db session variable
	 * This is bound to the schema and will fade away once this session is closed
	 * Annoyingly those values can't be escaped thru PDO
	 *
	 * @param $value When set to FALSE will RESET session value (aka UNSET)
	 */
	public static function setSession($key, $value = 'True') {
		$key = (isset(CONFIG::$config['postgres']['schema']) ? explode(',', CONFIG::$config['postgres']['schema'])[0] : 'cvedia') . '.' . str_replace(array('\'', '"'), '', $key);
		
		$query = $value === false ?
				'RESET "' . $key . '"'
			:
				'SET SESSION "' . $key . '" TO ' . $value;
		
		if (DEBUG::$debug) {
			$query = self::$db->commentQuery($query);
			DEBUG::debug($query);
		}
		
		$s = self::$db->prepare($query);
		$result = $s->execute();
		
		if ($result === false) {
			self::$errors[] = $s->errorInfo();
			DEBUG::debug('error:', $s->errorInfo());
			
			return false;
		}
		
		return $result;
	}
	
	public static function checkErrors($silent = false) {
		if (self::$db === false)
			return;
		
		$x = self::$db->errorInfo();
		
		if (!empty($x) && intval($x[0][0]) > 0) {
			self::$errors[] = $x;
			
			if (!$silent)
				DEBUG::debug('error:', $x);
		}
	}
}
