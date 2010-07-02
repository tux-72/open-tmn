-- MySQL dump 10.13  Distrib 5.1.45, for portbld-freebsd7.1 (amd64)
--
-- Host: localhost    Database: vlancontrol
-- ------------------------------------------------------
-- Server version	5.1.45

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Current Database: `vlancontrol`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `vlancontrol` /*!40100 DEFAULT CHARACTER SET latin1 */;

USE `vlancontrol`;

--
-- Table structure for table `ap_login_info`
--

DROP TABLE IF EXISTS `ap_login_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ap_login_info` (
  `login` varchar(30) NOT NULL,
  `hw_mac` varchar(17) NOT NULL,
  `start_date` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `last_date` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `port_id` int(11) NOT NULL DEFAULT '0',
  `ap_name` varchar(60) DEFAULT NULL,
  `sw_id` int(11) DEFAULT NULL,
  `vlan_id` int(11) DEFAULT NULL,
  `trust` tinyint(4) DEFAULT '0',
  `ip_addr` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`login`,`hw_mac`,`port_id`),
  KEY `switch` (`sw_id`),
  KEY `vlan` (`vlan_id`),
  KEY `trusted` (`trust`),
  KEY `ap` (`port_id`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bundle_jobs`
--

DROP TABLE IF EXISTS `bundle_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bundle_jobs` (
  `port_id` int(11) NOT NULL,
  `ltype_id` tinyint(4) NOT NULL DEFAULT '0',
  `job_id` int(11) NOT NULL AUTO_INCREMENT,
  `date_insert` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_exec` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `parm` varchar(200) NOT NULL DEFAULT '',
  `archiv` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`job_id`) USING BTREE,
  UNIQUE KEY `ch_id` (`port_id`,`ltype_id`,`archiv`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=438 DEFAULT CHARSET=koi8r CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `client_subnets`
--

DROP TABLE IF EXISTS `client_subnets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `client_subnets` (
  `ip1` int(11) NOT NULL DEFAULT '77',
  `ip2` int(11) NOT NULL DEFAULT '239',
  `ip3` int(11) NOT NULL DEFAULT '211',
  `ip4` int(11) NOT NULL DEFAULT '0',
  `subnet` varchar(20) DEFAULT NULL,
  `LOGIN` varchar(20) DEFAULT NULL,
  `info` varchar(60) DEFAULT NULL,
  `status` tinyint(4) NOT NULL,
  `conf` varchar(20) DEFAULT NULL,
  `vlan` int(11) DEFAULT NULL,
  PRIMARY KEY (`ip1`,`ip2`,`ip3`,`ip4`) USING BTREE,
  KEY `clients` (`LOGIN`) USING BTREE,
  KEY `state` (`status`),
  KEY `net` (`subnet`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER client_subnets_log_insert AFTER  insert ON client_subnets
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'client_subnets', CONCAT('info="', IFNULL(new.`info`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'client_subnets', CONCAT('status="', IFNULL(new.`status`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'client_subnets', CONCAT('ip4="', IFNULL(new.`ip4`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'client_subnets', CONCAT('vlan="', IFNULL(new.`vlan`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'client_subnets', CONCAT('conf="', IFNULL(new.`conf`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'client_subnets', CONCAT('LOGIN="', IFNULL(new.`LOGIN`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'client_subnets', CONCAT('ip2="', IFNULL(new.`ip2`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'client_subnets', CONCAT('ip1="', IFNULL(new.`ip1`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'client_subnets', CONCAT('ip3="', IFNULL(new.`ip3`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'client_subnets', CONCAT('subnet="', IFNULL(new.`subnet`,''),'"'));
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER client_subnets_log_update AFTER  update ON client_subnets
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'client_subnets', CONCAT('PK_ip4: from="', IFNULL(old.`ip4`,''), '" to="', IFNULL(new.`ip4`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'client_subnets', CONCAT('PK_ip2: from="', IFNULL(old.`ip2`,''), '" to="', IFNULL(new.`ip2`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'client_subnets', CONCAT('PK_ip1: from="', IFNULL(old.`ip1`,''), '" to="', IFNULL(new.`ip1`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'client_subnets', CONCAT('PK_ip3: from="', IFNULL(old.`ip3`,''), '" to="', IFNULL(new.`ip3`,''),'"')); IF IFNULL(old.`info`,'') != IFNULL(new.`info`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'client_subnets', CONCAT('info: from="', IFNULL(old.`info`,''), '" to="', IFNULL(new.`info`,''),'"'));
                        END IF; IF IFNULL(old.`status`,'') != IFNULL(new.`status`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'client_subnets', CONCAT('status: from="', IFNULL(old.`status`,''), '" to="', IFNULL(new.`status`,''),'"'));
                        END IF; IF IFNULL(old.`ip4`,'') != IFNULL(new.`ip4`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'client_subnets', CONCAT('ip4: from="', IFNULL(old.`ip4`,''), '" to="', IFNULL(new.`ip4`,''),'"'));
                        END IF; IF IFNULL(old.`vlan`,'') != IFNULL(new.`vlan`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'client_subnets', CONCAT('vlan: from="', IFNULL(old.`vlan`,''), '" to="', IFNULL(new.`vlan`,''),'"'));
                        END IF; IF IFNULL(old.`conf`,'') != IFNULL(new.`conf`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'client_subnets', CONCAT('conf: from="', IFNULL(old.`conf`,''), '" to="', IFNULL(new.`conf`,''),'"'));
                        END IF; IF IFNULL(old.`LOGIN`,'') != IFNULL(new.`LOGIN`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'client_subnets', CONCAT('LOGIN: from="', IFNULL(old.`LOGIN`,''), '" to="', IFNULL(new.`LOGIN`,''),'"'));
                        END IF; IF IFNULL(old.`ip2`,'') != IFNULL(new.`ip2`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'client_subnets', CONCAT('ip2: from="', IFNULL(old.`ip2`,''), '" to="', IFNULL(new.`ip2`,''),'"'));
                        END IF; IF IFNULL(old.`ip1`,'') != IFNULL(new.`ip1`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'client_subnets', CONCAT('ip1: from="', IFNULL(old.`ip1`,''), '" to="', IFNULL(new.`ip1`,''),'"'));
                        END IF; IF IFNULL(old.`ip3`,'') != IFNULL(new.`ip3`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'client_subnets', CONCAT('ip3: from="', IFNULL(old.`ip3`,''), '" to="', IFNULL(new.`ip3`,''),'"'));
                        END IF; IF IFNULL(old.`subnet`,'') != IFNULL(new.`subnet`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'client_subnets', CONCAT('subnet: from="', IFNULL(old.`subnet`,''), '" to="', IFNULL(new.`subnet`,''),'"'));
                        END IF;
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER client_subnets_log_delete AFTER  delete ON client_subnets
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'client_subnets', CONCAT('info="',IFNULL(old.`info`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'client_subnets', CONCAT('status="',IFNULL(old.`status`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'client_subnets', CONCAT('ip4="',IFNULL(old.`ip4`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'client_subnets', CONCAT('vlan="',IFNULL(old.`vlan`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'client_subnets', CONCAT('conf="',IFNULL(old.`conf`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'client_subnets', CONCAT('LOGIN="',IFNULL(old.`LOGIN`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'client_subnets', CONCAT('ip2="',IFNULL(old.`ip2`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'client_subnets', CONCAT('ip1="',IFNULL(old.`ip1`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'client_subnets', CONCAT('ip3="',IFNULL(old.`ip3`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'client_subnets', CONCAT('subnet="',IFNULL(old.`subnet`,''),'"') );
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `dhcp_addr`
--

DROP TABLE IF EXISTS `dhcp_addr`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dhcp_addr` (
  `pool_id` int(11) NOT NULL DEFAULT '0',
  `ip` varchar(15) NOT NULL,
  `login` varchar(30) DEFAULT NULL,
  `hw_mac` varchar(17) DEFAULT NULL,
  `vlan_id` int(11) DEFAULT NULL,
  `port_id` int(11) DEFAULT NULL,
  `start_use` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `start_lease` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `end_lease` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `session` varchar(50) DEFAULT NULL,
  `agent_info` varchar(70) DEFAULT NULL,
  `dhcp_vendor` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`ip`),
  KEY `vlan` (`vlan_id`),
  KEY `port_id` (`port_id`),
  KEY `lease` (`end_lease`),
  KEY `hw_mac` (`hw_mac`),
  KEY `user` (`login`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dhcp_addr_arch`
--

DROP TABLE IF EXISTS `dhcp_addr_arch`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dhcp_addr_arch` (
  `ip` varchar(15) NOT NULL,
  `login` varchar(30) NOT NULL,
  `hw_mac` varchar(17) DEFAULT NULL,
  `port_id` int(11) DEFAULT NULL,
  `agent_info` varchar(70) DEFAULT NULL,
  `start_use` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `end_use` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  KEY `IP` (`ip`),
  KEY `USER` (`login`),
  KEY `MAC` (`hw_mac`),
  KEY `AP` (`port_id`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER dhcp_addr_arch_log_insert AFTER  insert ON dhcp_addr_arch
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_addr_arch', CONCAT('end_use="', IFNULL(new.`end_use`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_addr_arch', CONCAT('agent_info="', IFNULL(new.`agent_info`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_addr_arch', CONCAT('hw_mac="', IFNULL(new.`hw_mac`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_addr_arch', CONCAT('start_use="', IFNULL(new.`start_use`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_addr_arch', CONCAT('ip="', IFNULL(new.`ip`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_addr_arch', CONCAT('port_id="', IFNULL(new.`port_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_addr_arch', CONCAT('login="', IFNULL(new.`login`,''),'"'));
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER dhcp_addr_arch_log_update AFTER  update ON dhcp_addr_arch
                FOR EACH ROW
                BEGIN IF IFNULL(old.`end_use`,'') != IFNULL(new.`end_use`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_addr_arch', CONCAT('end_use: from="', IFNULL(old.`end_use`,''), '" to="', IFNULL(new.`end_use`,''),'"'));
                        END IF; IF IFNULL(old.`agent_info`,'') != IFNULL(new.`agent_info`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_addr_arch', CONCAT('agent_info: from="', IFNULL(old.`agent_info`,''), '" to="', IFNULL(new.`agent_info`,''),'"'));
                        END IF; IF IFNULL(old.`hw_mac`,'') != IFNULL(new.`hw_mac`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_addr_arch', CONCAT('hw_mac: from="', IFNULL(old.`hw_mac`,''), '" to="', IFNULL(new.`hw_mac`,''),'"'));
                        END IF; IF IFNULL(old.`start_use`,'') != IFNULL(new.`start_use`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_addr_arch', CONCAT('start_use: from="', IFNULL(old.`start_use`,''), '" to="', IFNULL(new.`start_use`,''),'"'));
                        END IF; IF IFNULL(old.`ip`,'') != IFNULL(new.`ip`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_addr_arch', CONCAT('ip: from="', IFNULL(old.`ip`,''), '" to="', IFNULL(new.`ip`,''),'"'));
                        END IF; IF IFNULL(old.`port_id`,'') != IFNULL(new.`port_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_addr_arch', CONCAT('port_id: from="', IFNULL(old.`port_id`,''), '" to="', IFNULL(new.`port_id`,''),'"'));
                        END IF; IF IFNULL(old.`login`,'') != IFNULL(new.`login`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_addr_arch', CONCAT('login: from="', IFNULL(old.`login`,''), '" to="', IFNULL(new.`login`,''),'"'));
                        END IF;
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER dhcp_addr_arch_log_delete AFTER  delete ON dhcp_addr_arch
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_addr_arch', CONCAT('end_use="',IFNULL(old.`end_use`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_addr_arch', CONCAT('agent_info="',IFNULL(old.`agent_info`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_addr_arch', CONCAT('hw_mac="',IFNULL(old.`hw_mac`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_addr_arch', CONCAT('start_use="',IFNULL(old.`start_use`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_addr_arch', CONCAT('ip="',IFNULL(old.`ip`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_addr_arch', CONCAT('port_id="',IFNULL(old.`port_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_addr_arch', CONCAT('login="',IFNULL(old.`login`,''),'"') );
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `dhcp_pools`
--

DROP TABLE IF EXISTS `dhcp_pools`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dhcp_pools` (
  `pool_id` int(11) NOT NULL,
  `head_id` int(11) NOT NULL DEFAULT '3',
  `pool_name` varchar(50) DEFAULT NULL,
  `pool_type` int(11) NOT NULL DEFAULT '0',
  `subnet` varchar(18) DEFAULT NULL,
  `gw` varchar(15) DEFAULT NULL,
  `mask` varchar(15) NOT NULL,
  `dhcp_lease` int(11) NOT NULL DEFAULT '3600',
  `name_server` varchar(15) NOT NULL DEFAULT '77.239.208.17',
  PRIMARY KEY (`pool_id`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER dhcp_pools_log_insert AFTER  insert ON dhcp_pools
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_pools', CONCAT('static_ip="', IFNULL(new.`static_ip`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_pools', CONCAT('name_server="', IFNULL(new.`name_server`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_pools', CONCAT('gw="', IFNULL(new.`gw`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_pools', CONCAT('real_ip="', IFNULL(new.`real_ip`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_pools', CONCAT('head_id="', IFNULL(new.`head_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_pools', CONCAT('pool_id="', IFNULL(new.`pool_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_pools', CONCAT('dhcp_lease="', IFNULL(new.`dhcp_lease`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_pools', CONCAT('subnet="', IFNULL(new.`subnet`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_pools', CONCAT('pool_name="', IFNULL(new.`pool_name`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'dhcp_pools', CONCAT('mask="', IFNULL(new.`mask`,''),'"'));
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER dhcp_pools_log_update AFTER  update ON dhcp_pools
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'dhcp_pools', CONCAT('PK_pool_id: from="', IFNULL(old.`pool_id`,''), '" to="', IFNULL(new.`pool_id`,''),'"')); IF IFNULL(old.`static_ip`,'') != IFNULL(new.`static_ip`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_pools', CONCAT('static_ip: from="', IFNULL(old.`static_ip`,''), '" to="', IFNULL(new.`static_ip`,''),'"'));
                        END IF; IF IFNULL(old.`name_server`,'') != IFNULL(new.`name_server`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_pools', CONCAT('name_server: from="', IFNULL(old.`name_server`,''), '" to="', IFNULL(new.`name_server`,''),'"'));
                        END IF; IF IFNULL(old.`gw`,'') != IFNULL(new.`gw`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_pools', CONCAT('gw: from="', IFNULL(old.`gw`,''), '" to="', IFNULL(new.`gw`,''),'"'));
                        END IF; IF IFNULL(old.`real_ip`,'') != IFNULL(new.`real_ip`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_pools', CONCAT('real_ip: from="', IFNULL(old.`real_ip`,''), '" to="', IFNULL(new.`real_ip`,''),'"'));
                        END IF; IF IFNULL(old.`head_id`,'') != IFNULL(new.`head_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_pools', CONCAT('head_id: from="', IFNULL(old.`head_id`,''), '" to="', IFNULL(new.`head_id`,''),'"'));
                        END IF; IF IFNULL(old.`pool_id`,'') != IFNULL(new.`pool_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_pools', CONCAT('pool_id: from="', IFNULL(old.`pool_id`,''), '" to="', IFNULL(new.`pool_id`,''),'"'));
                        END IF; IF IFNULL(old.`dhcp_lease`,'') != IFNULL(new.`dhcp_lease`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_pools', CONCAT('dhcp_lease: from="', IFNULL(old.`dhcp_lease`,''), '" to="', IFNULL(new.`dhcp_lease`,''),'"'));
                        END IF; IF IFNULL(old.`subnet`,'') != IFNULL(new.`subnet`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_pools', CONCAT('subnet: from="', IFNULL(old.`subnet`,''), '" to="', IFNULL(new.`subnet`,''),'"'));
                        END IF; IF IFNULL(old.`pool_name`,'') != IFNULL(new.`pool_name`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_pools', CONCAT('pool_name: from="', IFNULL(old.`pool_name`,''), '" to="', IFNULL(new.`pool_name`,''),'"'));
                        END IF; IF IFNULL(old.`mask`,'') != IFNULL(new.`mask`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'dhcp_pools', CONCAT('mask: from="', IFNULL(old.`mask`,''), '" to="', IFNULL(new.`mask`,''),'"'));
                        END IF;
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER dhcp_pools_log_delete AFTER  delete ON dhcp_pools
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_pools', CONCAT('static_ip="',IFNULL(old.`static_ip`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_pools', CONCAT('name_server="',IFNULL(old.`name_server`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_pools', CONCAT('gw="',IFNULL(old.`gw`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_pools', CONCAT('real_ip="',IFNULL(old.`real_ip`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_pools', CONCAT('head_id="',IFNULL(old.`head_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_pools', CONCAT('pool_id="',IFNULL(old.`pool_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_pools', CONCAT('dhcp_lease="',IFNULL(old.`dhcp_lease`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_pools', CONCAT('subnet="',IFNULL(old.`subnet`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_pools', CONCAT('pool_name="',IFNULL(old.`pool_name`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'dhcp_pools', CONCAT('mask="',IFNULL(old.`mask`,''),'"') );
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `head_link`
--

DROP TABLE IF EXISTS `head_link`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `head_link` (
  `head_id` int(11) NOT NULL,
  `port_id` int(11) NOT NULL,
  `vlan_id` int(11) NOT NULL,
  `ip_subnet` varchar(18) DEFAULT NULL,
  `login` varchar(20) DEFAULT NULL,
  `head_iface` varchar(30) DEFAULT NULL,
  `pppoe_up` tinyint(4) NOT NULL DEFAULT '1',
  `communal` tinyint(4) NOT NULL DEFAULT '0',
  `status` tinyint(4) NOT NULL DEFAULT '1',
  `set_status` tinyint(4) DEFAULT NULL,
  `hw_mac` varchar(17) DEFAULT NULL,
  `white_static_ip` tinyint(4) DEFAULT '0',
  `inet_shape` int(11) NOT NULL DEFAULT '1000',
  `inet_priority` tinyint(4) NOT NULL DEFAULT '0',
  `dhcp_use` tinyint(4) NOT NULL DEFAULT '1',
  `stamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `desc` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`port_id`) USING BTREE,
  KEY `IP` (`ip_subnet`),
  KEY `Login` (`login`),
  KEY `status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `heads`
--

DROP TABLE IF EXISTS `heads`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `heads` (
  `head_id` tinyint(4) NOT NULL DEFAULT '0',
  `linked_head` tinyint(4) DEFAULT NULL,
  `zone_id` tinyint(4) DEFAULT NULL,
  `desc` varchar(100) CHARACTER SET latin1 DEFAULT NULL,
  `term_lib` varchar(20) DEFAULT NULL,
  `ltype_id` tinyint(4) DEFAULT NULL,
  `l2sw_id` int(11) DEFAULT NULL,
  `l2sw_portpref` varchar(20) DEFAULT NULL,
  `l2sw_port` int(11) DEFAULT NULL,
  `term_use` tinyint(1) DEFAULT '0',
  `term_ip` varchar(15) DEFAULT NULL,
  `term_portpref` varchar(20) DEFAULT NULL,
  `term_port` int(11) DEFAULT NULL,
  `vlan_min` int(11) DEFAULT NULL,
  `vlan_max` int(11) DEFAULT NULL,
  `login1` varchar(15) DEFAULT NULL,
  `pass1` varchar(12) DEFAULT NULL,
  `login2` varchar(15) DEFAULT NULL,
  `pass2` varchar(12) DEFAULT NULL,
  `loop_if` varchar(12) DEFAULT NULL,
  `dhcp_helper` varchar(15) DEFAULT NULL,
  `dhcp_relay_ip` varchar(15) DEFAULT NULL,
  `dhcp_relay_ip2` varchar(15) DEFAULT NULL,
  `up_acl-in` varchar(15) DEFAULT NULL,
  `up_acl-out` varchar(15) DEFAULT NULL,
  `down_acl-in` varchar(15) DEFAULT NULL,
  `down_acl-out` varchar(15) DEFAULT NULL,
  `term_grey_ip2` varchar(3) DEFAULT NULL,
  PRIMARY KEY (`head_id`),
  UNIQUE KEY `term_hosts` (`zone_id`,`ltype_id`,`term_ip`) USING BTREE,
  KEY `type` (`ltype_id`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r COMMENT='Head switches, VLAN terminators';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER heads_log_insert AFTER  insert ON heads
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('up_acl-in="', IFNULL(new.`up_acl-in`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('dhcp_relay_ip="', IFNULL(new.`dhcp_relay_ip`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('login1="', IFNULL(new.`login1`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('term_lib="', IFNULL(new.`term_lib`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('vlan_min="', IFNULL(new.`vlan_min`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('login2="', IFNULL(new.`login2`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('term_ip="', IFNULL(new.`term_ip`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('down_acl-out="', IFNULL(new.`down_acl-out`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('loop_if="', IFNULL(new.`loop_if`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('pass1="', IFNULL(new.`pass1`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('term_port="', IFNULL(new.`term_port`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('desc="', IFNULL(new.`desc`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('dhcp_helper="', IFNULL(new.`dhcp_helper`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('term_use="', IFNULL(new.`term_use`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('term_portpref="', IFNULL(new.`term_portpref`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('l2sw_port="', IFNULL(new.`l2sw_port`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('linked_head="', IFNULL(new.`linked_head`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('l2sw_portpref="', IFNULL(new.`l2sw_portpref`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('term_grey_ip2="', IFNULL(new.`term_grey_ip2`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('ltype_id="', IFNULL(new.`ltype_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('head_id="', IFNULL(new.`head_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('l2sw_id="', IFNULL(new.`l2sw_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('vlan_max="', IFNULL(new.`vlan_max`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('up_acl-out="', IFNULL(new.`up_acl-out`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('dhcp_relay_ip2="', IFNULL(new.`dhcp_relay_ip2`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('pass2="', IFNULL(new.`pass2`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('zone_id="', IFNULL(new.`zone_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'heads', CONCAT('down_acl-in="', IFNULL(new.`down_acl-in`,''),'"'));
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER heads_log_update AFTER  update ON heads
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'heads', CONCAT('PK_head_id: from="', IFNULL(old.`head_id`,''), '" to="', IFNULL(new.`head_id`,''),'"')); IF IFNULL(old.`up_acl-in`,'') != IFNULL(new.`up_acl-in`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('up_acl-in: from="', IFNULL(old.`up_acl-in`,''), '" to="', IFNULL(new.`up_acl-in`,''),'"'));
                        END IF; IF IFNULL(old.`dhcp_relay_ip`,'') != IFNULL(new.`dhcp_relay_ip`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('dhcp_relay_ip: from="', IFNULL(old.`dhcp_relay_ip`,''), '" to="', IFNULL(new.`dhcp_relay_ip`,''),'"'));
                        END IF; IF IFNULL(old.`login1`,'') != IFNULL(new.`login1`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('login1: from="', IFNULL(old.`login1`,''), '" to="', IFNULL(new.`login1`,''),'"'));
                        END IF; IF IFNULL(old.`term_lib`,'') != IFNULL(new.`term_lib`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('term_lib: from="', IFNULL(old.`term_lib`,''), '" to="', IFNULL(new.`term_lib`,''),'"'));
                        END IF; IF IFNULL(old.`vlan_min`,'') != IFNULL(new.`vlan_min`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('vlan_min: from="', IFNULL(old.`vlan_min`,''), '" to="', IFNULL(new.`vlan_min`,''),'"'));
                        END IF; IF IFNULL(old.`login2`,'') != IFNULL(new.`login2`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('login2: from="', IFNULL(old.`login2`,''), '" to="', IFNULL(new.`login2`,''),'"'));
                        END IF; IF IFNULL(old.`term_ip`,'') != IFNULL(new.`term_ip`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('term_ip: from="', IFNULL(old.`term_ip`,''), '" to="', IFNULL(new.`term_ip`,''),'"'));
                        END IF; IF IFNULL(old.`down_acl-out`,'') != IFNULL(new.`down_acl-out`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('down_acl-out: from="', IFNULL(old.`down_acl-out`,''), '" to="', IFNULL(new.`down_acl-out`,''),'"'));
                        END IF; IF IFNULL(old.`loop_if`,'') != IFNULL(new.`loop_if`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('loop_if: from="', IFNULL(old.`loop_if`,''), '" to="', IFNULL(new.`loop_if`,''),'"'));
                        END IF; IF IFNULL(old.`pass1`,'') != IFNULL(new.`pass1`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('pass1: from="', IFNULL(old.`pass1`,''), '" to="', IFNULL(new.`pass1`,''),'"'));
                        END IF; IF IFNULL(old.`term_port`,'') != IFNULL(new.`term_port`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('term_port: from="', IFNULL(old.`term_port`,''), '" to="', IFNULL(new.`term_port`,''),'"'));
                        END IF; IF IFNULL(old.`desc`,'') != IFNULL(new.`desc`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('desc: from="', IFNULL(old.`desc`,''), '" to="', IFNULL(new.`desc`,''),'"'));
                        END IF; IF IFNULL(old.`dhcp_helper`,'') != IFNULL(new.`dhcp_helper`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('dhcp_helper: from="', IFNULL(old.`dhcp_helper`,''), '" to="', IFNULL(new.`dhcp_helper`,''),'"'));
                        END IF; IF IFNULL(old.`term_use`,'') != IFNULL(new.`term_use`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('term_use: from="', IFNULL(old.`term_use`,''), '" to="', IFNULL(new.`term_use`,''),'"'));
                        END IF; IF IFNULL(old.`term_portpref`,'') != IFNULL(new.`term_portpref`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('term_portpref: from="', IFNULL(old.`term_portpref`,''), '" to="', IFNULL(new.`term_portpref`,''),'"'));
                        END IF; IF IFNULL(old.`l2sw_port`,'') != IFNULL(new.`l2sw_port`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('l2sw_port: from="', IFNULL(old.`l2sw_port`,''), '" to="', IFNULL(new.`l2sw_port`,''),'"'));
                        END IF; IF IFNULL(old.`linked_head`,'') != IFNULL(new.`linked_head`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('linked_head: from="', IFNULL(old.`linked_head`,''), '" to="', IFNULL(new.`linked_head`,''),'"'));
                        END IF; IF IFNULL(old.`l2sw_portpref`,'') != IFNULL(new.`l2sw_portpref`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('l2sw_portpref: from="', IFNULL(old.`l2sw_portpref`,''), '" to="', IFNULL(new.`l2sw_portpref`,''),'"'));
                        END IF; IF IFNULL(old.`term_grey_ip2`,'') != IFNULL(new.`term_grey_ip2`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('term_grey_ip2: from="', IFNULL(old.`term_grey_ip2`,''), '" to="', IFNULL(new.`term_grey_ip2`,''),'"'));
                        END IF; IF IFNULL(old.`ltype_id`,'') != IFNULL(new.`ltype_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('ltype_id: from="', IFNULL(old.`ltype_id`,''), '" to="', IFNULL(new.`ltype_id`,''),'"'));
                        END IF; IF IFNULL(old.`head_id`,'') != IFNULL(new.`head_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('head_id: from="', IFNULL(old.`head_id`,''), '" to="', IFNULL(new.`head_id`,''),'"'));
                        END IF; IF IFNULL(old.`l2sw_id`,'') != IFNULL(new.`l2sw_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('l2sw_id: from="', IFNULL(old.`l2sw_id`,''), '" to="', IFNULL(new.`l2sw_id`,''),'"'));
                        END IF; IF IFNULL(old.`vlan_max`,'') != IFNULL(new.`vlan_max`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('vlan_max: from="', IFNULL(old.`vlan_max`,''), '" to="', IFNULL(new.`vlan_max`,''),'"'));
                        END IF; IF IFNULL(old.`up_acl-out`,'') != IFNULL(new.`up_acl-out`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('up_acl-out: from="', IFNULL(old.`up_acl-out`,''), '" to="', IFNULL(new.`up_acl-out`,''),'"'));
                        END IF; IF IFNULL(old.`dhcp_relay_ip2`,'') != IFNULL(new.`dhcp_relay_ip2`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('dhcp_relay_ip2: from="', IFNULL(old.`dhcp_relay_ip2`,''), '" to="', IFNULL(new.`dhcp_relay_ip2`,''),'"'));
                        END IF; IF IFNULL(old.`pass2`,'') != IFNULL(new.`pass2`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('pass2: from="', IFNULL(old.`pass2`,''), '" to="', IFNULL(new.`pass2`,''),'"'));
                        END IF; IF IFNULL(old.`zone_id`,'') != IFNULL(new.`zone_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('zone_id: from="', IFNULL(old.`zone_id`,''), '" to="', IFNULL(new.`zone_id`,''),'"'));
                        END IF; IF IFNULL(old.`down_acl-in`,'') != IFNULL(new.`down_acl-in`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'heads', CONCAT('down_acl-in: from="', IFNULL(old.`down_acl-in`,''), '" to="', IFNULL(new.`down_acl-in`,''),'"'));
                        END IF;
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER heads_log_delete AFTER  delete ON heads
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('up_acl-in="',IFNULL(old.`up_acl-in`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('dhcp_relay_ip="',IFNULL(old.`dhcp_relay_ip`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('login1="',IFNULL(old.`login1`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('term_lib="',IFNULL(old.`term_lib`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('vlan_min="',IFNULL(old.`vlan_min`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('login2="',IFNULL(old.`login2`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('term_ip="',IFNULL(old.`term_ip`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('down_acl-out="',IFNULL(old.`down_acl-out`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('loop_if="',IFNULL(old.`loop_if`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('pass1="',IFNULL(old.`pass1`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('term_port="',IFNULL(old.`term_port`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('desc="',IFNULL(old.`desc`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('dhcp_helper="',IFNULL(old.`dhcp_helper`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('term_use="',IFNULL(old.`term_use`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('term_portpref="',IFNULL(old.`term_portpref`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('l2sw_port="',IFNULL(old.`l2sw_port`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('linked_head="',IFNULL(old.`linked_head`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('l2sw_portpref="',IFNULL(old.`l2sw_portpref`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('term_grey_ip2="',IFNULL(old.`term_grey_ip2`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('ltype_id="',IFNULL(old.`ltype_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('head_id="',IFNULL(old.`head_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('l2sw_id="',IFNULL(old.`l2sw_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('vlan_max="',IFNULL(old.`vlan_max`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('up_acl-out="',IFNULL(old.`up_acl-out`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('dhcp_relay_ip2="',IFNULL(old.`dhcp_relay_ip2`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('pass2="',IFNULL(old.`pass2`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('zone_id="',IFNULL(old.`zone_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'heads', CONCAT('down_acl-in="',IFNULL(old.`down_acl-in`,''),'"') );
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `hosts`
--

DROP TABLE IF EXISTS `hosts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `hosts` (
  `sw_id` int(11) NOT NULL AUTO_INCREMENT,
  `hw_mac` varchar(17) DEFAULT NULL,
  `hostname` varchar(40) NOT NULL,
  `visible` tinyint(1) NOT NULL DEFAULT '1',
  `model_id` int(11) NOT NULL,
  `ip` varchar(15) NOT NULL DEFAULT '0.0.0.0',
  `bw_ctl` tinyint(1) NOT NULL DEFAULT '0',
  `automanage` tinyint(1) NOT NULL DEFAULT '0',
  `uplink_port` int(11) DEFAULT NULL,
  `uplink_portpref` varchar(20) DEFAULT NULL,
  `parent` int(11) DEFAULT NULL,
  `parent_port` int(11) DEFAULT NULL,
  `parent_portpref` varchar(20) DEFAULT NULL,
  `street_id` int(11) NOT NULL,
  `dom` varchar(30) NOT NULL,
  `podezd` int(11) NOT NULL DEFAULT '0',
  `unit` int(11) DEFAULT NULL,
  `grp` varchar(15) NOT NULL,
  `stamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `clients_vlan` int(11) DEFAULT NULL,
  `parent_ext` varchar(40) DEFAULT NULL,
  `zone_id` int(11) DEFAULT '1',
  `control_vlan` int(11) DEFAULT '1',
  PRIMARY KEY (`sw_id`),
  UNIQUE KEY `hostname` (`hostname`),
  UNIQUE KEY `ip` (`ip`),
  UNIQUE KEY `hw_mac` (`hw_mac`),
  UNIQUE KEY `cli_vlan` (`clients_vlan`),
  UNIQUE KEY `sw_unit` (`street_id`,`dom`,`podezd`,`unit`) USING BTREE,
  KEY `swmodel` (`model_id`),
  KEY `house` (`street_id`,`dom`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=355 DEFAULT CHARSET=koi8r CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER hosts_log_insert AFTER  insert ON hosts
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('street_id="', IFNULL(new.`street_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('ip="', IFNULL(new.`ip`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('model_id="', IFNULL(new.`model_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('hostname="', IFNULL(new.`hostname`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('control_vlan="', IFNULL(new.`control_vlan`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('stamp="', IFNULL(new.`stamp`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('parent_port="', IFNULL(new.`parent_port`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('parent_ext="', IFNULL(new.`parent_ext`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('bw_ctl="', IFNULL(new.`bw_ctl`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('parent_portpref="', IFNULL(new.`parent_portpref`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('sw_id="', IFNULL(new.`sw_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('automanage="', IFNULL(new.`automanage`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('hw_mac="', IFNULL(new.`hw_mac`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('visible="', IFNULL(new.`visible`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('parent="', IFNULL(new.`parent`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('dom="', IFNULL(new.`dom`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('podezd="', IFNULL(new.`podezd`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('uplink_port="', IFNULL(new.`uplink_port`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('uplink_portpref="', IFNULL(new.`uplink_portpref`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('unit="', IFNULL(new.`unit`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('grp="', IFNULL(new.`grp`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('zone_id="', IFNULL(new.`zone_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'hosts', CONCAT('clients_vlan="', IFNULL(new.`clients_vlan`,''),'"'));
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER hosts_log_update AFTER  update ON hosts
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'hosts', CONCAT('PK_sw_id: from="', IFNULL(old.`sw_id`,''), '" to="', IFNULL(new.`sw_id`,''),'"')); IF IFNULL(old.`street_id`,'') != IFNULL(new.`street_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('street_id: from="', IFNULL(old.`street_id`,''), '" to="', IFNULL(new.`street_id`,''),'"'));
                        END IF; IF IFNULL(old.`ip`,'') != IFNULL(new.`ip`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('ip: from="', IFNULL(old.`ip`,''), '" to="', IFNULL(new.`ip`,''),'"'));
                        END IF; IF IFNULL(old.`model_id`,'') != IFNULL(new.`model_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('model_id: from="', IFNULL(old.`model_id`,''), '" to="', IFNULL(new.`model_id`,''),'"'));
                        END IF; IF IFNULL(old.`hostname`,'') != IFNULL(new.`hostname`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('hostname: from="', IFNULL(old.`hostname`,''), '" to="', IFNULL(new.`hostname`,''),'"'));
                        END IF; IF IFNULL(old.`control_vlan`,'') != IFNULL(new.`control_vlan`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('control_vlan: from="', IFNULL(old.`control_vlan`,''), '" to="', IFNULL(new.`control_vlan`,''),'"'));
                        END IF; IF IFNULL(old.`stamp`,'') != IFNULL(new.`stamp`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('stamp: from="', IFNULL(old.`stamp`,''), '" to="', IFNULL(new.`stamp`,''),'"'));
                        END IF; IF IFNULL(old.`parent_port`,'') != IFNULL(new.`parent_port`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('parent_port: from="', IFNULL(old.`parent_port`,''), '" to="', IFNULL(new.`parent_port`,''),'"'));
                        END IF; IF IFNULL(old.`parent_ext`,'') != IFNULL(new.`parent_ext`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('parent_ext: from="', IFNULL(old.`parent_ext`,''), '" to="', IFNULL(new.`parent_ext`,''),'"'));
                        END IF; IF IFNULL(old.`bw_ctl`,'') != IFNULL(new.`bw_ctl`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('bw_ctl: from="', IFNULL(old.`bw_ctl`,''), '" to="', IFNULL(new.`bw_ctl`,''),'"'));
                        END IF; IF IFNULL(old.`parent_portpref`,'') != IFNULL(new.`parent_portpref`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('parent_portpref: from="', IFNULL(old.`parent_portpref`,''), '" to="', IFNULL(new.`parent_portpref`,''),'"'));
                        END IF; IF IFNULL(old.`sw_id`,'') != IFNULL(new.`sw_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('sw_id: from="', IFNULL(old.`sw_id`,''), '" to="', IFNULL(new.`sw_id`,''),'"'));
                        END IF; IF IFNULL(old.`automanage`,'') != IFNULL(new.`automanage`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('automanage: from="', IFNULL(old.`automanage`,''), '" to="', IFNULL(new.`automanage`,''),'"'));
                        END IF; IF IFNULL(old.`hw_mac`,'') != IFNULL(new.`hw_mac`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('hw_mac: from="', IFNULL(old.`hw_mac`,''), '" to="', IFNULL(new.`hw_mac`,''),'"'));
                        END IF; IF IFNULL(old.`visible`,'') != IFNULL(new.`visible`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('visible: from="', IFNULL(old.`visible`,''), '" to="', IFNULL(new.`visible`,''),'"'));
                        END IF; IF IFNULL(old.`parent`,'') != IFNULL(new.`parent`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('parent: from="', IFNULL(old.`parent`,''), '" to="', IFNULL(new.`parent`,''),'"'));
                        END IF; IF IFNULL(old.`dom`,'') != IFNULL(new.`dom`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('dom: from="', IFNULL(old.`dom`,''), '" to="', IFNULL(new.`dom`,''),'"'));
                        END IF; IF IFNULL(old.`podezd`,'') != IFNULL(new.`podezd`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('podezd: from="', IFNULL(old.`podezd`,''), '" to="', IFNULL(new.`podezd`,''),'"'));
                        END IF; IF IFNULL(old.`uplink_port`,'') != IFNULL(new.`uplink_port`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('uplink_port: from="', IFNULL(old.`uplink_port`,''), '" to="', IFNULL(new.`uplink_port`,''),'"'));
                        END IF; IF IFNULL(old.`uplink_portpref`,'') != IFNULL(new.`uplink_portpref`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('uplink_portpref: from="', IFNULL(old.`uplink_portpref`,''), '" to="', IFNULL(new.`uplink_portpref`,''),'"'));
                        END IF; IF IFNULL(old.`unit`,'') != IFNULL(new.`unit`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('unit: from="', IFNULL(old.`unit`,''), '" to="', IFNULL(new.`unit`,''),'"'));
                        END IF; IF IFNULL(old.`grp`,'') != IFNULL(new.`grp`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('grp: from="', IFNULL(old.`grp`,''), '" to="', IFNULL(new.`grp`,''),'"'));
                        END IF; IF IFNULL(old.`zone_id`,'') != IFNULL(new.`zone_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('zone_id: from="', IFNULL(old.`zone_id`,''), '" to="', IFNULL(new.`zone_id`,''),'"'));
                        END IF; IF IFNULL(old.`clients_vlan`,'') != IFNULL(new.`clients_vlan`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'hosts', CONCAT('clients_vlan: from="', IFNULL(old.`clients_vlan`,''), '" to="', IFNULL(new.`clients_vlan`,''),'"'));
                        END IF;
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER hosts_log_delete AFTER  delete ON hosts
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('street_id="',IFNULL(old.`street_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('ip="',IFNULL(old.`ip`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('model_id="',IFNULL(old.`model_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('hostname="',IFNULL(old.`hostname`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('control_vlan="',IFNULL(old.`control_vlan`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('stamp="',IFNULL(old.`stamp`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('parent_port="',IFNULL(old.`parent_port`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('parent_ext="',IFNULL(old.`parent_ext`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('bw_ctl="',IFNULL(old.`bw_ctl`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('parent_portpref="',IFNULL(old.`parent_portpref`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('sw_id="',IFNULL(old.`sw_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('automanage="',IFNULL(old.`automanage`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('hw_mac="',IFNULL(old.`hw_mac`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('visible="',IFNULL(old.`visible`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('parent="',IFNULL(old.`parent`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('dom="',IFNULL(old.`dom`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('podezd="',IFNULL(old.`podezd`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('uplink_port="',IFNULL(old.`uplink_port`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('uplink_portpref="',IFNULL(old.`uplink_portpref`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('unit="',IFNULL(old.`unit`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('grp="',IFNULL(old.`grp`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('zone_id="',IFNULL(old.`zone_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'hosts', CONCAT('clients_vlan="',IFNULL(old.`clients_vlan`,''),'"') );
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `link_types`
--

DROP TABLE IF EXISTS `link_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `link_types` (
  `ltype_id` int(11) NOT NULL,
  `ltype_name` varchar(15) NOT NULL,
  `desc` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`ltype_id`),
  KEY `name` (`ltype_name`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER link_types_log_insert AFTER  insert ON link_types
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'link_types', CONCAT('ltype_id="', IFNULL(new.`ltype_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'link_types', CONCAT('desc="', IFNULL(new.`desc`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'link_types', CONCAT('ltype_name="', IFNULL(new.`ltype_name`,''),'"'));
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER link_types_log_update AFTER  update ON link_types
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'link_types', CONCAT('PK_ltype_id: from="', IFNULL(old.`ltype_id`,''), '" to="', IFNULL(new.`ltype_id`,''),'"')); IF IFNULL(old.`ltype_id`,'') != IFNULL(new.`ltype_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'link_types', CONCAT('ltype_id: from="', IFNULL(old.`ltype_id`,''), '" to="', IFNULL(new.`ltype_id`,''),'"'));
                        END IF; IF IFNULL(old.`desc`,'') != IFNULL(new.`desc`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'link_types', CONCAT('desc: from="', IFNULL(old.`desc`,''), '" to="', IFNULL(new.`desc`,''),'"'));
                        END IF; IF IFNULL(old.`ltype_name`,'') != IFNULL(new.`ltype_name`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'link_types', CONCAT('ltype_name: from="', IFNULL(old.`ltype_name`,''), '" to="', IFNULL(new.`ltype_name`,''),'"'));
                        END IF;
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER link_types_log_delete AFTER  delete ON link_types
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'link_types', CONCAT('ltype_id="',IFNULL(old.`ltype_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'link_types', CONCAT('desc="',IFNULL(old.`desc`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'link_types', CONCAT('ltype_name="',IFNULL(old.`ltype_name`,''),'"') );
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `log`
--

DROP TABLE IF EXISTS `log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `event` varchar(20) NOT NULL,
  `table` varchar(255) NOT NULL,
  `time` datetime NOT NULL,
  `changes` varchar(4096) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=56385 DEFAULT CHARSET=koi8r;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `models`
--

DROP TABLE IF EXISTS `models`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `models` (
  `model_id` int(11) NOT NULL,
  `model_name` varchar(255) NOT NULL,
  `template` varchar(255) NOT NULL DEFAULT '',
  `extra` varchar(255) NOT NULL DEFAULT '',
  `comment` varchar(255) NOT NULL DEFAULT '',
  `image` varchar(255) DEFAULT NULL,
  `lastuserport` int(11) NOT NULL,
  `def_trunk` int(11) NOT NULL,
  `manage` tinyint(4) NOT NULL DEFAULT '0',
  `lib` varchar(15) DEFAULT NULL,
  `admin_login` varchar(15) NOT NULL DEFAULT 'admin',
  `admin_pass` varchar(12) NOT NULL,
  `ena_pass` varchar(15) DEFAULT NULL,
  `mon_login` varchar(15) NOT NULL DEFAULT 'swmon',
  `mon_pass` varchar(12) NOT NULL,
  `bw_free` int(11) DEFAULT '0',
  `rocom` varchar(30) DEFAULT NULL,
  `rwcom` varchar(30) DEFAULT NULL,
  `snmp_ap_fix` tinyint(4) DEFAULT '0',
  `old_admin` varchar(15) DEFAULT NULL,
  `old_pass` varchar(12) DEFAULT NULL,
  `sysDescr` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`model_id`),
  UNIQUE KEY `id` (`model_id`),
  UNIQUE KEY `model` (`model_name`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER models_log_insert AFTER  insert ON models
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('model_id="', IFNULL(new.`model_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('lastuserport="', IFNULL(new.`lastuserport`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('mon_pass="', IFNULL(new.`mon_pass`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('model_name="', IFNULL(new.`model_name`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('rwcom="', IFNULL(new.`rwcom`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('rocom="', IFNULL(new.`rocom`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('sysDescr="', IFNULL(new.`sysDescr`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('lib="', IFNULL(new.`lib`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('extra="', IFNULL(new.`extra`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('admin_login="', IFNULL(new.`admin_login`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('mon_login="', IFNULL(new.`mon_login`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('template="', IFNULL(new.`template`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('snmp_ap_fix="', IFNULL(new.`snmp_ap_fix`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('image="', IFNULL(new.`image`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('ena_pass="', IFNULL(new.`ena_pass`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('def_trunk="', IFNULL(new.`def_trunk`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('bw_free="', IFNULL(new.`bw_free`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('comment="', IFNULL(new.`comment`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('old_admin="', IFNULL(new.`old_admin`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('old_pass="', IFNULL(new.`old_pass`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('admin_pass="', IFNULL(new.`admin_pass`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'models', CONCAT('manage="', IFNULL(new.`manage`,''),'"'));
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER models_log_update AFTER  update ON models
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'models', CONCAT('PK_model_id: from="', IFNULL(old.`model_id`,''), '" to="', IFNULL(new.`model_id`,''),'"')); IF IFNULL(old.`model_id`,'') != IFNULL(new.`model_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('model_id: from="', IFNULL(old.`model_id`,''), '" to="', IFNULL(new.`model_id`,''),'"'));
                        END IF; IF IFNULL(old.`lastuserport`,'') != IFNULL(new.`lastuserport`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('lastuserport: from="', IFNULL(old.`lastuserport`,''), '" to="', IFNULL(new.`lastuserport`,''),'"'));
                        END IF; IF IFNULL(old.`mon_pass`,'') != IFNULL(new.`mon_pass`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('mon_pass: from="', IFNULL(old.`mon_pass`,''), '" to="', IFNULL(new.`mon_pass`,''),'"'));
                        END IF; IF IFNULL(old.`model_name`,'') != IFNULL(new.`model_name`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('model_name: from="', IFNULL(old.`model_name`,''), '" to="', IFNULL(new.`model_name`,''),'"'));
                        END IF; IF IFNULL(old.`rwcom`,'') != IFNULL(new.`rwcom`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('rwcom: from="', IFNULL(old.`rwcom`,''), '" to="', IFNULL(new.`rwcom`,''),'"'));
                        END IF; IF IFNULL(old.`rocom`,'') != IFNULL(new.`rocom`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('rocom: from="', IFNULL(old.`rocom`,''), '" to="', IFNULL(new.`rocom`,''),'"'));
                        END IF; IF IFNULL(old.`sysDescr`,'') != IFNULL(new.`sysDescr`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('sysDescr: from="', IFNULL(old.`sysDescr`,''), '" to="', IFNULL(new.`sysDescr`,''),'"'));
                        END IF; IF IFNULL(old.`lib`,'') != IFNULL(new.`lib`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('lib: from="', IFNULL(old.`lib`,''), '" to="', IFNULL(new.`lib`,''),'"'));
                        END IF; IF IFNULL(old.`extra`,'') != IFNULL(new.`extra`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('extra: from="', IFNULL(old.`extra`,''), '" to="', IFNULL(new.`extra`,''),'"'));
                        END IF; IF IFNULL(old.`admin_login`,'') != IFNULL(new.`admin_login`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('admin_login: from="', IFNULL(old.`admin_login`,''), '" to="', IFNULL(new.`admin_login`,''),'"'));
                        END IF; IF IFNULL(old.`mon_login`,'') != IFNULL(new.`mon_login`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('mon_login: from="', IFNULL(old.`mon_login`,''), '" to="', IFNULL(new.`mon_login`,''),'"'));
                        END IF; IF IFNULL(old.`template`,'') != IFNULL(new.`template`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('template: from="', IFNULL(old.`template`,''), '" to="', IFNULL(new.`template`,''),'"'));
                        END IF; IF IFNULL(old.`snmp_ap_fix`,'') != IFNULL(new.`snmp_ap_fix`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('snmp_ap_fix: from="', IFNULL(old.`snmp_ap_fix`,''), '" to="', IFNULL(new.`snmp_ap_fix`,''),'"'));
                        END IF; IF IFNULL(old.`image`,'') != IFNULL(new.`image`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('image: from="', IFNULL(old.`image`,''), '" to="', IFNULL(new.`image`,''),'"'));
                        END IF; IF IFNULL(old.`ena_pass`,'') != IFNULL(new.`ena_pass`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('ena_pass: from="', IFNULL(old.`ena_pass`,''), '" to="', IFNULL(new.`ena_pass`,''),'"'));
                        END IF; IF IFNULL(old.`def_trunk`,'') != IFNULL(new.`def_trunk`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('def_trunk: from="', IFNULL(old.`def_trunk`,''), '" to="', IFNULL(new.`def_trunk`,''),'"'));
                        END IF; IF IFNULL(old.`bw_free`,'') != IFNULL(new.`bw_free`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('bw_free: from="', IFNULL(old.`bw_free`,''), '" to="', IFNULL(new.`bw_free`,''),'"'));
                        END IF; IF IFNULL(old.`comment`,'') != IFNULL(new.`comment`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('comment: from="', IFNULL(old.`comment`,''), '" to="', IFNULL(new.`comment`,''),'"'));
                        END IF; IF IFNULL(old.`old_admin`,'') != IFNULL(new.`old_admin`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('old_admin: from="', IFNULL(old.`old_admin`,''), '" to="', IFNULL(new.`old_admin`,''),'"'));
                        END IF; IF IFNULL(old.`old_pass`,'') != IFNULL(new.`old_pass`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('old_pass: from="', IFNULL(old.`old_pass`,''), '" to="', IFNULL(new.`old_pass`,''),'"'));
                        END IF; IF IFNULL(old.`admin_pass`,'') != IFNULL(new.`admin_pass`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('admin_pass: from="', IFNULL(old.`admin_pass`,''), '" to="', IFNULL(new.`admin_pass`,''),'"'));
                        END IF; IF IFNULL(old.`manage`,'') != IFNULL(new.`manage`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'models', CONCAT('manage: from="', IFNULL(old.`manage`,''), '" to="', IFNULL(new.`manage`,''),'"'));
                        END IF;
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER models_log_delete AFTER  delete ON models
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('model_id="',IFNULL(old.`model_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('lastuserport="',IFNULL(old.`lastuserport`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('mon_pass="',IFNULL(old.`mon_pass`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('model_name="',IFNULL(old.`model_name`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('rwcom="',IFNULL(old.`rwcom`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('rocom="',IFNULL(old.`rocom`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('sysDescr="',IFNULL(old.`sysDescr`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('lib="',IFNULL(old.`lib`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('extra="',IFNULL(old.`extra`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('admin_login="',IFNULL(old.`admin_login`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('mon_login="',IFNULL(old.`mon_login`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('template="',IFNULL(old.`template`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('snmp_ap_fix="',IFNULL(old.`snmp_ap_fix`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('image="',IFNULL(old.`image`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('ena_pass="',IFNULL(old.`ena_pass`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('def_trunk="',IFNULL(old.`def_trunk`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('bw_free="',IFNULL(old.`bw_free`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('comment="',IFNULL(old.`comment`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('old_admin="',IFNULL(old.`old_admin`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('old_pass="',IFNULL(old.`old_pass`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('admin_pass="',IFNULL(old.`admin_pass`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'models', CONCAT('manage="',IFNULL(old.`manage`,''),'"') );
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `phy_types`
--

DROP TABLE IF EXISTS `phy_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `phy_types` (
  `phy_id` int(11) NOT NULL,
  `phy_name` varchar(40) NOT NULL,
  `desc` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`phy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER phy_types_log_insert AFTER  insert ON phy_types
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'phy_types', CONCAT('phy_name="', IFNULL(new.`phy_name`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'phy_types', CONCAT('phy_id="', IFNULL(new.`phy_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'phy_types', CONCAT('desc="', IFNULL(new.`desc`,''),'"'));
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER phy_types_log_update AFTER  update ON phy_types
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'phy_types', CONCAT('PK_phy_id: from="', IFNULL(old.`phy_id`,''), '" to="', IFNULL(new.`phy_id`,''),'"')); IF IFNULL(old.`phy_name`,'') != IFNULL(new.`phy_name`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'phy_types', CONCAT('phy_name: from="', IFNULL(old.`phy_name`,''), '" to="', IFNULL(new.`phy_name`,''),'"'));
                        END IF; IF IFNULL(old.`phy_id`,'') != IFNULL(new.`phy_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'phy_types', CONCAT('phy_id: from="', IFNULL(old.`phy_id`,''), '" to="', IFNULL(new.`phy_id`,''),'"'));
                        END IF; IF IFNULL(old.`desc`,'') != IFNULL(new.`desc`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'phy_types', CONCAT('desc: from="', IFNULL(old.`desc`,''), '" to="', IFNULL(new.`desc`,''),'"'));
                        END IF;
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER phy_types_log_delete AFTER  delete ON phy_types
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'phy_types', CONCAT('phy_name="',IFNULL(old.`phy_name`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'phy_types', CONCAT('phy_id="',IFNULL(old.`phy_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'phy_types', CONCAT('desc="',IFNULL(old.`desc`,''),'"') );
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `pool_types`
--

DROP TABLE IF EXISTS `pool_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `pool_types` (
  `pool_type` int(11) NOT NULL,
  `name_type` varchar(50) NOT NULL,
  PRIMARY KEY (`pool_type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `port_vlantag`
--

DROP TABLE IF EXISTS `port_vlantag`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `port_vlantag` (
  `port_id` int(11) NOT NULL,
  `vlan_id` int(11) NOT NULL DEFAULT '0',
  `tag` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`port_id`,`vlan_id`),
  KEY `tag` (`tag`),
  KEY `vlan` (`vlan_id`),
  KEY `port` (`port_id`),
  CONSTRAINT `port_id` FOREIGN KEY (`port_id`) REFERENCES `swports` (`port_id`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER port_vlantag_log_insert AFTER  insert ON port_vlantag
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'port_vlantag', CONCAT('port_id="', IFNULL(new.`port_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'port_vlantag', CONCAT('tag="', IFNULL(new.`tag`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'port_vlantag', CONCAT('vlan_id="', IFNULL(new.`vlan_id`,''),'"'));
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER port_vlantag_log_update AFTER  update ON port_vlantag
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'port_vlantag', CONCAT('PK_port_id: from="', IFNULL(old.`port_id`,''), '" to="', IFNULL(new.`port_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'port_vlantag', CONCAT('PK_vlan_id: from="', IFNULL(old.`vlan_id`,''), '" to="', IFNULL(new.`vlan_id`,''),'"')); IF IFNULL(old.`port_id`,'') != IFNULL(new.`port_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'port_vlantag', CONCAT('port_id: from="', IFNULL(old.`port_id`,''), '" to="', IFNULL(new.`port_id`,''),'"'));
                        END IF; IF IFNULL(old.`tag`,'') != IFNULL(new.`tag`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'port_vlantag', CONCAT('tag: from="', IFNULL(old.`tag`,''), '" to="', IFNULL(new.`tag`,''),'"'));
                        END IF; IF IFNULL(old.`vlan_id`,'') != IFNULL(new.`vlan_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'port_vlantag', CONCAT('vlan_id: from="', IFNULL(old.`vlan_id`,''), '" to="', IFNULL(new.`vlan_id`,''),'"'));
                        END IF;
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER port_vlantag_log_delete AFTER  delete ON port_vlantag
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'port_vlantag', CONCAT('port_id="',IFNULL(old.`port_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'port_vlantag', CONCAT('tag="',IFNULL(old.`tag`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'port_vlantag', CONCAT('vlan_id="',IFNULL(old.`vlan_id`,''),'"') );
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `streets`
--

DROP TABLE IF EXISTS `streets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `streets` (
  `street_id` int(11) NOT NULL,
  `street_name` varchar(50) NOT NULL,
  PRIMARY KEY (`street_id`),
  KEY `names` (`street_name`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=koi8r;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER streets_log_insert AFTER  insert ON streets
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'streets', CONCAT('street_id="', IFNULL(new.`street_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'streets', CONCAT('street_name="', IFNULL(new.`street_name`,''),'"'));
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER streets_log_update AFTER  update ON streets
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'streets', CONCAT('PK_street_id: from="', IFNULL(old.`street_id`,''), '" to="', IFNULL(new.`street_id`,''),'"')); IF IFNULL(old.`street_id`,'') != IFNULL(new.`street_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'streets', CONCAT('street_id: from="', IFNULL(old.`street_id`,''), '" to="', IFNULL(new.`street_id`,''),'"'));
                        END IF; IF IFNULL(old.`street_name`,'') != IFNULL(new.`street_name`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'streets', CONCAT('street_name: from="', IFNULL(old.`street_name`,''), '" to="', IFNULL(new.`street_name`,''),'"'));
                        END IF;
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER streets_log_delete AFTER  delete ON streets
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'streets', CONCAT('street_id="',IFNULL(old.`street_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'streets', CONCAT('street_name="',IFNULL(old.`street_name`,''),'"') );
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `swports`
--

DROP TABLE IF EXISTS `swports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `swports` (
  `snmp_idx` int(11) DEFAULT NULL,
  `port_id` int(11) NOT NULL AUTO_INCREMENT,
  `ltype_id` tinyint(4) DEFAULT '20',
  `communal` tinyint(1) NOT NULL DEFAULT '0',
  `type` tinyint(4) NOT NULL DEFAULT '1',
  `sw_id` int(11) NOT NULL,
  `portpref` varchar(20) DEFAULT NULL,
  `port` int(11) NOT NULL,
  `status` tinyint(1) NOT NULL DEFAULT '1',
  `ds_speed` int(11) DEFAULT '-1',
  `us_speed` int(11) DEFAULT '-1',
  `info` varchar(60) DEFAULT NULL,
  `start_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `vlan_id` int(11) DEFAULT '-1',
  `tag` tinyint(1) NOT NULL DEFAULT '0',
  `unique_vlan` tinyint(1) NOT NULL DEFAULT '0',
  `maxhwaddr` tinyint(4) NOT NULL DEFAULT '-1',
  `head_id` int(11) DEFAULT NULL,
  `phy_id` int(11) DEFAULT '1',
  `autoneg` tinyint(1) DEFAULT '1',
  `speed` int(11) DEFAULT NULL,
  `duplex` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`port_id`) USING BTREE,
  UNIQUE KEY `id` (`port_id`),
  UNIQUE KEY `AP` (`sw_id`,`portpref`,`port`,`vlan_id`,`type`) USING BTREE,
  KEY `link_type` (`ltype_id`) USING BTREE,
  KEY `head` (`head_id`),
  KEY `PHY` (`phy_id`),
  CONSTRAINT `switch` FOREIGN KEY (`sw_id`) REFERENCES `hosts` (`sw_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5372 DEFAULT CHARSET=koi8r CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER swports_log_insert AFTER  insert ON swports
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('status="', IFNULL(new.`status`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('snmp_idx="', IFNULL(new.`snmp_idx`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('port_id="', IFNULL(new.`port_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('communal="', IFNULL(new.`communal`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('speed="', IFNULL(new.`speed`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('unique_vlan="', IFNULL(new.`unique_vlan`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('sw_id="', IFNULL(new.`sw_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('tag="', IFNULL(new.`tag`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('start_date="', IFNULL(new.`start_date`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('info="', IFNULL(new.`info`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('us_speed="', IFNULL(new.`us_speed`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('ds_speed="', IFNULL(new.`ds_speed`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('maxhwaddr="', IFNULL(new.`maxhwaddr`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('port="', IFNULL(new.`port`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('duplex="', IFNULL(new.`duplex`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('vlan_id="', IFNULL(new.`vlan_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('ltype_id="', IFNULL(new.`ltype_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('head_id="', IFNULL(new.`head_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('phy_id="', IFNULL(new.`phy_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('portpref="', IFNULL(new.`portpref`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('autoneg="', IFNULL(new.`autoneg`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'swports', CONCAT('type="', IFNULL(new.`type`,''),'"'));
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER swports_log_update AFTER  update ON swports
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'swports', CONCAT('PK_port_id: from="', IFNULL(old.`port_id`,''), '" to="', IFNULL(new.`port_id`,''),'"')); IF IFNULL(old.`status`,'') != IFNULL(new.`status`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('status: from="', IFNULL(old.`status`,''), '" to="', IFNULL(new.`status`,''),'"'));
                        END IF; IF IFNULL(old.`snmp_idx`,'') != IFNULL(new.`snmp_idx`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('snmp_idx: from="', IFNULL(old.`snmp_idx`,''), '" to="', IFNULL(new.`snmp_idx`,''),'"'));
                        END IF; IF IFNULL(old.`port_id`,'') != IFNULL(new.`port_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('port_id: from="', IFNULL(old.`port_id`,''), '" to="', IFNULL(new.`port_id`,''),'"'));
                        END IF; IF IFNULL(old.`communal`,'') != IFNULL(new.`communal`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('communal: from="', IFNULL(old.`communal`,''), '" to="', IFNULL(new.`communal`,''),'"'));
                        END IF; IF IFNULL(old.`speed`,'') != IFNULL(new.`speed`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('speed: from="', IFNULL(old.`speed`,''), '" to="', IFNULL(new.`speed`,''),'"'));
                        END IF; IF IFNULL(old.`unique_vlan`,'') != IFNULL(new.`unique_vlan`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('unique_vlan: from="', IFNULL(old.`unique_vlan`,''), '" to="', IFNULL(new.`unique_vlan`,''),'"'));
                        END IF; IF IFNULL(old.`sw_id`,'') != IFNULL(new.`sw_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('sw_id: from="', IFNULL(old.`sw_id`,''), '" to="', IFNULL(new.`sw_id`,''),'"'));
                        END IF; IF IFNULL(old.`tag`,'') != IFNULL(new.`tag`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('tag: from="', IFNULL(old.`tag`,''), '" to="', IFNULL(new.`tag`,''),'"'));
                        END IF; IF IFNULL(old.`start_date`,'') != IFNULL(new.`start_date`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('start_date: from="', IFNULL(old.`start_date`,''), '" to="', IFNULL(new.`start_date`,''),'"'));
                        END IF; IF IFNULL(old.`info`,'') != IFNULL(new.`info`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('info: from="', IFNULL(old.`info`,''), '" to="', IFNULL(new.`info`,''),'"'));
                        END IF; IF IFNULL(old.`us_speed`,'') != IFNULL(new.`us_speed`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('us_speed: from="', IFNULL(old.`us_speed`,''), '" to="', IFNULL(new.`us_speed`,''),'"'));
                        END IF; IF IFNULL(old.`ds_speed`,'') != IFNULL(new.`ds_speed`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('ds_speed: from="', IFNULL(old.`ds_speed`,''), '" to="', IFNULL(new.`ds_speed`,''),'"'));
                        END IF; IF IFNULL(old.`maxhwaddr`,'') != IFNULL(new.`maxhwaddr`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('maxhwaddr: from="', IFNULL(old.`maxhwaddr`,''), '" to="', IFNULL(new.`maxhwaddr`,''),'"'));
                        END IF; IF IFNULL(old.`port`,'') != IFNULL(new.`port`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('port: from="', IFNULL(old.`port`,''), '" to="', IFNULL(new.`port`,''),'"'));
                        END IF; IF IFNULL(old.`duplex`,'') != IFNULL(new.`duplex`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('duplex: from="', IFNULL(old.`duplex`,''), '" to="', IFNULL(new.`duplex`,''),'"'));
                        END IF; IF IFNULL(old.`vlan_id`,'') != IFNULL(new.`vlan_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('vlan_id: from="', IFNULL(old.`vlan_id`,''), '" to="', IFNULL(new.`vlan_id`,''),'"'));
                        END IF; IF IFNULL(old.`ltype_id`,'') != IFNULL(new.`ltype_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('ltype_id: from="', IFNULL(old.`ltype_id`,''), '" to="', IFNULL(new.`ltype_id`,''),'"'));
                        END IF; IF IFNULL(old.`head_id`,'') != IFNULL(new.`head_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('head_id: from="', IFNULL(old.`head_id`,''), '" to="', IFNULL(new.`head_id`,''),'"'));
                        END IF; IF IFNULL(old.`phy_id`,'') != IFNULL(new.`phy_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('phy_id: from="', IFNULL(old.`phy_id`,''), '" to="', IFNULL(new.`phy_id`,''),'"'));
                        END IF; IF IFNULL(old.`portpref`,'') != IFNULL(new.`portpref`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('portpref: from="', IFNULL(old.`portpref`,''), '" to="', IFNULL(new.`portpref`,''),'"'));
                        END IF; IF IFNULL(old.`autoneg`,'') != IFNULL(new.`autoneg`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('autoneg: from="', IFNULL(old.`autoneg`,''), '" to="', IFNULL(new.`autoneg`,''),'"'));
                        END IF; IF IFNULL(old.`type`,'') != IFNULL(new.`type`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'swports', CONCAT('type: from="', IFNULL(old.`type`,''), '" to="', IFNULL(new.`type`,''),'"'));
                        END IF;
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER swports_log_delete AFTER  delete ON swports
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('status="',IFNULL(old.`status`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('snmp_idx="',IFNULL(old.`snmp_idx`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('port_id="',IFNULL(old.`port_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('communal="',IFNULL(old.`communal`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('speed="',IFNULL(old.`speed`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('unique_vlan="',IFNULL(old.`unique_vlan`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('sw_id="',IFNULL(old.`sw_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('tag="',IFNULL(old.`tag`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('start_date="',IFNULL(old.`start_date`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('info="',IFNULL(old.`info`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('us_speed="',IFNULL(old.`us_speed`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('ds_speed="',IFNULL(old.`ds_speed`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('maxhwaddr="',IFNULL(old.`maxhwaddr`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('port="',IFNULL(old.`port`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('duplex="',IFNULL(old.`duplex`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('vlan_id="',IFNULL(old.`vlan_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('ltype_id="',IFNULL(old.`ltype_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('head_id="',IFNULL(old.`head_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('phy_id="',IFNULL(old.`phy_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('portpref="',IFNULL(old.`portpref`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('autoneg="',IFNULL(old.`autoneg`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'swports', CONCAT('type="',IFNULL(old.`type`,''),'"') );
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `vlan_list`
--

DROP TABLE IF EXISTS `vlan_list`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `vlan_list` (
  `vlan_id` int(11) NOT NULL DEFAULT '0',
  `zone_id` int(2) NOT NULL DEFAULT '-1',
  `port_id` int(11) DEFAULT NULL,
  `ltype_id` int(11) NOT NULL,
  `info` varchar(60) DEFAULT NULL,
  `desc` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`zone_id`,`vlan_id`) USING BTREE,
  UNIQUE KEY `PORTVLAN` (`vlan_id`,`zone_id`,`port_id`),
  KEY `Link_type` (`ltype_id`),
  KEY `AP` (`port_id`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER vlan_list_log_insert AFTER  insert ON vlan_list
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'vlan_list', CONCAT('info="', IFNULL(new.`info`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'vlan_list', CONCAT('ltype_id="', IFNULL(new.`ltype_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'vlan_list', CONCAT('desc="', IFNULL(new.`desc`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'vlan_list', CONCAT('port_id="', IFNULL(new.`port_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'vlan_list', CONCAT('zone_id="', IFNULL(new.`zone_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'vlan_list', CONCAT('vlan_id="', IFNULL(new.`vlan_id`,''),'"'));
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER vlan_list_log_update AFTER  update ON vlan_list
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'vlan_list', CONCAT('PK_zone_id: from="', IFNULL(old.`zone_id`,''), '" to="', IFNULL(new.`zone_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'vlan_list', CONCAT('PK_vlan_id: from="', IFNULL(old.`vlan_id`,''), '" to="', IFNULL(new.`vlan_id`,''),'"')); IF IFNULL(old.`info`,'') != IFNULL(new.`info`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'vlan_list', CONCAT('info: from="', IFNULL(old.`info`,''), '" to="', IFNULL(new.`info`,''),'"'));
                        END IF; IF IFNULL(old.`ltype_id`,'') != IFNULL(new.`ltype_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'vlan_list', CONCAT('ltype_id: from="', IFNULL(old.`ltype_id`,''), '" to="', IFNULL(new.`ltype_id`,''),'"'));
                        END IF; IF IFNULL(old.`desc`,'') != IFNULL(new.`desc`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'vlan_list', CONCAT('desc: from="', IFNULL(old.`desc`,''), '" to="', IFNULL(new.`desc`,''),'"'));
                        END IF; IF IFNULL(old.`port_id`,'') != IFNULL(new.`port_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'vlan_list', CONCAT('port_id: from="', IFNULL(old.`port_id`,''), '" to="', IFNULL(new.`port_id`,''),'"'));
                        END IF; IF IFNULL(old.`zone_id`,'') != IFNULL(new.`zone_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'vlan_list', CONCAT('zone_id: from="', IFNULL(old.`zone_id`,''), '" to="', IFNULL(new.`zone_id`,''),'"'));
                        END IF; IF IFNULL(old.`vlan_id`,'') != IFNULL(new.`vlan_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'vlan_list', CONCAT('vlan_id: from="', IFNULL(old.`vlan_id`,''), '" to="', IFNULL(new.`vlan_id`,''),'"'));
                        END IF;
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER vlan_list_log_delete AFTER  delete ON vlan_list
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'vlan_list', CONCAT('info="',IFNULL(old.`info`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'vlan_list', CONCAT('ltype_id="',IFNULL(old.`ltype_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'vlan_list', CONCAT('desc="',IFNULL(old.`desc`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'vlan_list', CONCAT('port_id="',IFNULL(old.`port_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'vlan_list', CONCAT('zone_id="',IFNULL(old.`zone_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'vlan_list', CONCAT('vlan_id="',IFNULL(old.`vlan_id`,''),'"') );
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `vlan_zones`
--

DROP TABLE IF EXISTS `vlan_zones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `vlan_zones` (
  `zone_id` tinyint(4) NOT NULL,
  `zone_name` varchar(20) NOT NULL,
  `desc` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`zone_id`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER vlan_zones_log_insert AFTER  insert ON vlan_zones
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'vlan_zones', CONCAT('desc="', IFNULL(new.`desc`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'vlan_zones', CONCAT('zone_id="', IFNULL(new.`zone_id`,''),'"')); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'insert', 'vlan_zones', CONCAT('zone_name="', IFNULL(new.`zone_name`,''),'"'));
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER vlan_zones_log_update AFTER  update ON vlan_zones
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'update', 'vlan_zones', CONCAT('PK_zone_id: from="', IFNULL(old.`zone_id`,''), '" to="', IFNULL(new.`zone_id`,''),'"')); IF IFNULL(old.`desc`,'') != IFNULL(new.`desc`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'vlan_zones', CONCAT('desc: from="', IFNULL(old.`desc`,''), '" to="', IFNULL(new.`desc`,''),'"'));
                        END IF; IF IFNULL(old.`zone_id`,'') != IFNULL(new.`zone_id`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'vlan_zones', CONCAT('zone_id: from="', IFNULL(old.`zone_id`,''), '" to="', IFNULL(new.`zone_id`,''),'"'));
                        END IF; IF IFNULL(old.`zone_name`,'') != IFNULL(new.`zone_name`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), 'update', 'vlan_zones', CONCAT('zone_name: from="', IFNULL(old.`zone_name`,''), '" to="', IFNULL(new.`zone_name`,''),'"'));
                        END IF;
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = koi8r */ ;
/*!50003 SET character_set_results = koi8r */ ;
/*!50003 SET collation_connection  = koi8r_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`swweb`@`192.168.29.22`*/ /*!50003 TRIGGER vlan_zones_log_delete AFTER  delete ON vlan_zones
                FOR EACH ROW
                BEGIN INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'vlan_zones', CONCAT('desc="',IFNULL(old.`desc`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'vlan_zones', CONCAT('zone_id="',IFNULL(old.`zone_id`,''),'"') ); INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), 'delete', 'vlan_zones', CONCAT('zone_name="',IFNULL(old.`zone_name`,''),'"') );
                    
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2010-07-02 13:00:24
