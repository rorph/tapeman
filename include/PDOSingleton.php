<?php

/**
 * PDO SINGLETON CLASS
 *
 * Based on:
 *
 * @author Tony Landis
 * @link http://www.tonylandis.com
 * @license Use how you like it, just please don't remove or alter this PHPDoc
 *
 * WSA PDO Singleton ADODB fully compatible
 *
 * @author Rodrigo Moraes Orph <rodrigo.orph@gmail.com>
 * @version 1.52.1
 *
 * @notes
 *
 * This is mainly needed to create an compatibility layer with adodb but also to
 * avoid falling out standards when querying the database, all known adodb functions
 * are present, when needed adding new ones isen't a problem.
 *
 * @warning
 *
 * The original class was very limited and had several issues, it shouldn't be
 * taken in consideration on updates at all.
 *
 * - Rod
 *
 * @todo mysqli compatibility
 *
 */

class PDOSingleton {
	/**
	 * @var PDOSingleton
	 */
	public static $PDOInstance;
	public static $debug = false;
	protected $fetchMode = PDO::FETCH_ASSOC;

	/**
	 * Force return of a ADODB-like object on ADODB methods when set to
	 * FALSE; When set to TRUE this will behave like PDO.
	 *
	 * Note that there's an overhead on returning data as ADODB.
	 *
	 */
	public static $ADODB_QUERY_POLICY = true;

	public static $_k = 1; // total queries
	public static $_t = 0; // total time spent on queries

	/**
	 * Creates a PDO instance representing a connection to a database and makes the instance available as a singleton
	 *
	 * @param string $dsn The full DSN, eg: mysql:host=localhost;dbname=testdb
	 * @param string $username The user name for the DSN string. This parameter is optional for some PDO drivers.
	 * @param string $password The password for the DSN string. This parameter is optional for some PDO drivers.
	 * @param array $driver_options A key=>value array of driver-specific connection options
	 *
	 * @return PDO
	 */
	public function __construct($dsn, $username=false, $password=false, $driver_options=false) {
		global $__PDOInstance;

		if (!self::$PDOInstance) {
			if ($driver_options === false && DEV_ENV)
				$driver_options = array(
					PDO::ATTR_PERSISTENT => true,
					PDO::ATTR_ERRMODE => PDO::ERRMODE_WARNING
				);

			try {
				if (!isset($__PDOInstance) || !is_object($__PDOInstance)) {
					if (self::$debug) {
						$__PDOInstance = new PDODebug(
							$dsn,
							$username,
							$password,
							empty($driver_options) || $driver_options === false || !is_array($driver_options) ? array() : $driver_options
						);

						register_shutdown_function('PDOSingleton::debug_summary');
					} else {
						$__PDOInstance = new PDO(
							$dsn,
							$username,
							$password,
							empty($driver_options) || $driver_options === false || !is_array($driver_options) ? array() : $driver_options
						);
					}
				}

				self::$PDOInstance = &$__PDOInstance;
				# self::$PDOInstance->fetchMode = $this->fetchMode;
				self::debug(self::$debug); // replicate debug flag from singleton to pdo instance
			} catch (PDOException $e) {
				 die("PDO CONNECTION ERROR: " . $e->getMessage() . "<br/>\n");
			}
		}
		return self::$PDOInstance;
	}

	/**
	 * Initiates a transaction
	 *
	 * @return bool
	 */
	public static function beginTransaction() {
		return self::$PDOInstance->beginTransaction();
	}

	/**
	 * Commits a transaction
	 *
	 * @return bool
	 */
	public static function commit() {
		return self::$PDOInstance->commit();
	}

	/**
	 * Do debugging?
	 *
	 * @param bool $debugging
	 */
	public static function debug($debug) {
		self::$PDOInstance->debug = (bool) $debug;
		if(self::$PDOInstance->debug) {
			self::$PDOInstance->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
		} else {
			self::$PDOInstance->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_SILENT);
		}
	}

	public static function debug_summary() {
		echo "\n*** QUERY_SUMMARY: " . self::$_k . " queries, " . self::$_t . "s\n";
	}

	/**
	 * Fetch the SQLSTATE associated with the last operation on the database handle
	 *
	 * @return string
	 */
	public static function errorCode() {
		return self::$PDOInstance->errorCode();
	}

	/**
	 * Fetch extended error information associated with the last operation on the database handle
	 *
	 * @return array
	 */
	public static function errorInfo() {
		return self::$PDOInstance->errorInfo();
	}

	/**
	 * Execute an SQL statement and return the number of affected rows
	 *
	 * @param string $statement
	 */
	public static function exec($statement) {
		$statement = self::commentQuery($statement);
		try {
			if(self::$PDOInstance->debug) echo "$statement<hr>";
				return self::$PDOInstance->exec($statement);
		} catch(PDOException $e) {
			die("DB Exception: ".$e->getMessage()."<hr>");
		}
	}

	/**
	 * Retrieve a database connection attribute
	 *
	 * @param int $attribute
	 * @return mixed
	 */
	public static function getAttribute($attribute) {
		return self::$PDOInstance->getAttribute($attribute);
	}

	/**
	 * Return an array of available PDO drivers
	 *
	 * @return array
	 */
	public static function getAvailableDrivers(){
		return self::$PDOInstance->getAvailableDrivers();
	}

	/**
	 * Returns the ID of the last inserted row or sequence value
	 *
	 * @param string $name Name of the sequence object from which the ID should be returned.
	 * @return string
	 */
	public static function lastInsertId($name=false) {
		return self::$PDOInstance->lastInsertId($name);
	}

	/**
	 * Alias of lastInsertId
	 */
	public function Insert_ID() {
		return self::lastInsertId();
	}

	/**
	 * Prepares a statement for execution and returns a statement object
	 *
	 * @param string $statement A valid SQL statement for the target database server
	 * @param array $driver_options Array of one or more key=>value pairs to set attribute values for the PDOStatement obj returned
	 * @return PDOStatement
	 */
	public static function prepare($statement, $driver_options=false) {
		$statement = self::commentQuery($statement);

		if (!$driver_options)
			$driver_options=array();
		return self::$PDOInstance->prepare($statement, $driver_options);
	}

	/**
	 * Executes an SQL statement, returning a result set as a PDOStatement object
	 *
	 * @param string $statement
	 * @return PDOStatement
	 */
	public static function query($statement) {
		$statement = self::commentQuery($statement);
		try {
			return self::$PDOInstance->query($statement);
		} catch(PDOException $e) {
			die("DB Exception: ".$e->getMessage()."<hr>");
		}
	}

	/**
	 * Execute query and return all rows in assoc array
	 *
	 * @param string $statement
	 * @return array
	 */
	public function getAll($statement, $fetchMode=null) {
		$statement = self::commentQuery($statement);
		$res = self::$PDOInstance->query($statement);

		if ($res)
			return $res->fetchAll($fetchMode ? $fetchMode : $this->fetchMode);
			# return $res->fetchAll($fetchMode ? $fetchMode : self::$PDOInstance->fetchMode);
		else
			return array();
	}

	/**
	 * Execute query and return one row in assoc array
	 *
	 * @param string $statement
	 * @return array
	 */
	public function getRow($statement) {
		$statement = self::commentQuery($statement);
		$res = self::$PDOInstance->query($statement);

		if ($res)
			return $res->fetch($this->fetchMode);
		else
			return array();
	}

	/**
	 * Execute query and return one value only
	 *
	 * @param string $statement
	 * @return mixed
	 */
	/*
	public function getOne($statement) {
		$res = self::$PDOInstance->query($statement);

		if ($res) {
			$return = $res->fetchColumn();
			if (empty($return))
				return null;

			return is_array($return) ? $return[0] : $return;
		} else {
			return null;
		}
	}
	*/
	public function getOne($statement) {
		$statement = self::commentQuery($statement);
		$res = self::$PDOInstance->query($statement);

		if ($res)
			return $res->fetchColumn();
		else
			return null;
	}

	/**
	 * Execute query and select one column only
	 *
	 * @param string $statement
	 * @return mixed
	 */
	public function getCol($statement) {
		$statement = self::commentQuery($statement);
		$res = self::$PDOInstance->query($statement);
        return $res ? $res->fetchColumn() : array();
	}

	/**
	 * Execute query and return all rows in assoc array
	 *
	 * @param string $statement
	 * @return array
	 */
	public static function queryFetchAllAssoc($statement) {
		$statement = self::commentQuery($statement);
		return self::$PDOInstance->query($statement)->fetchAll(self::$PDOInstance->fetchMode);
	}

	/**
	 * Execute query and return one row in assoc array
	 *
	 * @param string $statement
	 * @return array
	 */
	public static function queryFetchRowAssoc($statement) {
		$statement = self::commentQuery($statement);
		return self::$PDOInstance->query($statement)->fetch(self::$PDOInstance->fetchMode);
	}

	/**
	 * Execute query and select one column only
	 *
	 * @param string $statement
	 * @return mixed
	 */
	public static function queryFetchColAssoc($statement) {
		$statement = self::commentQuery($statement);
		return self::$PDOInstance->query($statement)->fetchColumn();
	}

	/**
	 * Quotes a string for use in a query
	 *
	 * @param string $input
	 * @param int $parameter_type
	 * @return string
	 */
	public static function quote($input, $parameter_type=0) {
		return self::$PDOInstance->quote($input, $parameter_type);
	}

	/**
	 * Rolls back a transaction
	 *
	 * @return bool
	 */
	public static function rollBack() {
		return self::$PDOInstance->rollBack();
	}

	/**
	 * Set an attribute
	 *
	 * @param int $attribute
	 * @param mixed $value
	 * @return bool
	 */
	public static function setAttribute($attribute, $value  ) {
		return self::$PDOInstance->setAttribute($attribute, $value);
	}

	/**
	 * Do not call this ever! Only exists for adodb backwards compatibility
	 *
	 * @todo Refactor existing code that calls this
	 */
	public static function qstr($string) { return self::quote($string); }

	/**
	 * Do not call this ever! Only exists for adodb backwards compatibility
	 *
	 * @todo Refactor existing code that calls this
	 *
	 * @return ADODOB_PDOStatement
	 */
	public static function Execute($statement, $simple = null) {
		$stmt = self::query($statement);

		if (!$stmt)
			return false;

		if ($simple === null)
			$simple = self::$ADODB_QUERY_POLICY;


		return $simple ? true : new ADODOB_PDOStatement($stmt);
	}

	public static function check() {
		if (!is_object(self::$PDOInstance))
			self::$PDOInstance = &$GLOBALS["__PDOInstance"];
	}

	public function SetFetchMode($mode) {
		switch ($mode) {
			// there are other methods avail, but we will keep only this 2 by now
			case PDO::FETCH_BOTH:
				self::$PDOInstance->fetchMode = PDO::FETCH_BOTH;
				break;

			default:
				self::$PDOInstance->fetchMode = PDO::FETCH_ASSOC;
				break;
		}
	}

	public static function commentQuery($query)
	{
		$trace = debug_backtrace(!DEBUG_BACKTRACE_PROVIDE_OBJECT | DEBUG_BACKTRACE_IGNORE_ARGS, 2);

		return
			'/* FILE: ' . @$trace[1]['file'] . ' @ ' . @$trace[1]['line'].' : ' . (isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : 'CLI') . ' */ '
			. $query;
	}
	
	public static function close() {
		global $__PDOInstance;
		
		self::$PDOInstance = null;
		$__PDOInstance = null;
		unset($__PDOInstance);
	}
}

class PDODebug extends PDO {
	public $fetchMode = PDO::FETCH_ASSOC;
	
	public function query($statement) {
		try {
			echo "$statement<hr>\n";

			$_start = microtime(true);
			$return = parent::query($statement);
			$time = (microtime(true) - $_start);
			echo '*** [' . PDOSingleton::$_k . '] ' . ($time > .4 ? 'SLOW_' : '') . 'QUERY_TIME: ' . $time . "s<hr>\n";

			PDOSingleton::$_k++;
			PDOSingleton::$_t += $time;

				return $return;
		} catch(PDOException $e) {
			die("DB Exception: ".$e->getMessage()."<hr>");
		}
	}
}
