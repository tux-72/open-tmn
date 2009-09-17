-- MySQL dump 10.13  Distrib 5.1.26-rc, for portbld-freebsd7.0 (amd64)
--
-- Host: localhost    Database: switchnet
-- ------------------------------------------------------
-- Server version	5.1.26-rc

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
-- Current Database: `switchnet`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `switchnet` /*!40100 DEFAULT CHARACTER SET latin1 */;

USE `switchnet`;

--
-- Table structure for table `autoconf_type`
--

DROP TABLE IF EXISTS `autoconf_type`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `autoconf_type` (
  `id` tinyint(4) NOT NULL DEFAULT '0',
  `name` varchar(15) NOT NULL,
  `desc` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `client_subnets`
--

DROP TABLE IF EXISTS `client_subnets`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
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
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `cmd_queue`
--

DROP TABLE IF EXISTS `cmd_queue`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `cmd_queue` (
  `port_id` int(11) NOT NULL,
  `action_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `run_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `archive` tinyint(1) NOT NULL,
  `action` varchar(50) NOT NULL,
  `act_parms` varchar(255) NOT NULL,
  PRIMARY KEY (`port_id`,`action_time`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `conf`
--

DROP TABLE IF EXISTS `conf`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `conf` (
  `name` varchar(20) CHARACTER SET latin1 NOT NULL,
  `val` varchar(100) CHARACTER SET latin1 NOT NULL,
  PRIMARY KEY (`name`) USING BTREE,
  KEY `val` (`val`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `head_link`
--

DROP TABLE IF EXISTS `head_link`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `head_link` (
  `head_id` int(11) NOT NULL,
  `port_id` int(11) NOT NULL,
  `vlan_id` int(11) NOT NULL,
  `ip_subnet` varchar(18) DEFAULT NULL,
  `login` varchar(20) DEFAULT NULL,
  `head_iface` varchar(30) DEFAULT NULL,
  `status` tinyint(4) NOT NULL DEFAULT '1',
  `set_status` tinyint(4) NOT NULL DEFAULT '0',
  `desc` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`port_id`) USING BTREE,
  KEY `IP` (`ip_subnet`),
  KEY `Login` (`login`),
  KEY `status` (`status`),
  KEY `set_status` (`set_status`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `heads`
--

DROP TABLE IF EXISTS `heads`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `heads` (
  `head_id` tinyint(4) NOT NULL DEFAULT '0',
  `linked_head` tinyint(4) DEFAULT NULL,
  `vlan_zone` tinyint(4) DEFAULT NULL,
  `desc` varchar(100) CHARACTER SET latin1 DEFAULT NULL,
  `term_lib` varchar(20) DEFAULT NULL,
  `head_type` tinyint(4) DEFAULT NULL,
  `l2sw_id` int(11) DEFAULT NULL,
  `l2sw_portpref` varchar(20) DEFAULT NULL,
  `l2sw_port` int(11) DEFAULT NULL,
  `term_use` tinyint(1) DEFAULT '0',
  `term_id` int(11) DEFAULT NULL,
  `term_ip` varchar(15) DEFAULT NULL,
  `term_portpref` varchar(20) DEFAULT NULL,
  `term_port` int(11) DEFAULT NULL,
  `vlan_min` int(11) DEFAULT NULL,
  `vlan_max` int(11) DEFAULT NULL,
  `login1` varchar(15) DEFAULT NULL,
  `pass1` varchar(12) DEFAULT NULL,
  `login2` varchar(15) DEFAULT NULL,
  `pass2` varchar(12) DEFAULT NULL,
  `up_acl-in` varchar(15) DEFAULT NULL,
  `up_acl-out` varchar(15) DEFAULT NULL,
  `down_acl-in` varchar(15) DEFAULT NULL,
  `down_acl-out` varchar(15) DEFAULT NULL,
  `term_grey_ip2` varchar(3) DEFAULT NULL,
  PRIMARY KEY (`head_id`),
  UNIQUE KEY `term_hosts` (`vlan_zone`,`head_type`,`term_ip`) USING BTREE,
  KEY `type` (`head_type`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r COMMENT='Head switches, VLAN terminators';
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `hosts`
--

DROP TABLE IF EXISTS `hosts`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `hosts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `hw_mac` varchar(17) DEFAULT NULL,
  `hostname` varchar(40) NOT NULL,
  `visible` tinyint(1) NOT NULL DEFAULT '1',
  `model` int(11) NOT NULL,
  `ip` varchar(15) NOT NULL DEFAULT '0.0.0.0',
  `bw_ctl` tinyint(1) NOT NULL DEFAULT '0',
  `automanage` tinyint(1) NOT NULL DEFAULT '0',
  `uplink_port` int(11) DEFAULT NULL,
  `uplink_portpref` varchar(20) DEFAULT NULL,
  `parent` int(11) DEFAULT NULL,
  `parent_port` int(11) DEFAULT NULL,
  `parent_portpref` varchar(20) DEFAULT NULL,
  `idhouse` int(11) NOT NULL,
  `podezd` int(11) NOT NULL DEFAULT '0',
  `grp` varchar(15) NOT NULL,
  `conffile` varchar(50) DEFAULT NULL,
  `stamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `clients_vlan` int(11) DEFAULT NULL,
  `parent_ext` varchar(40) DEFAULT NULL,
  `vlan_zone` int(11) DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `hostname` (`hostname`),
  UNIQUE KEY `ip` (`ip`),
  UNIQUE KEY `hw_mac` (`hw_mac`),
  UNIQUE KEY `cli_vlan` (`clients_vlan`),
  KEY `swmodel` (`model`),
  KEY `house` (`idhouse`),
  CONSTRAINT `idmodel` FOREIGN KEY (`model`) REFERENCES `models` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=279 DEFAULT CHARSET=koi8r CHECKSUM=1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `houses`
--

DROP TABLE IF EXISTS `houses`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `houses` (
  `idhouse` int(11) NOT NULL,
  `idstreet` int(11) NOT NULL,
  `dom` varchar(10) DEFAULT NULL,
  `Street` varchar(60) NOT NULL,
  PRIMARY KEY (`idhouse`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=koi8r;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `link_types`
--

DROP TABLE IF EXISTS `link_types`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `link_types` (
  `id` int(11) NOT NULL,
  `name` varchar(15) NOT NULL,
  `desc` varchar(100) DEFAULT NULL,
  `vlan_range` int(11) DEFAULT NULL,
  `old_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r CHECKSUM=1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `models`
--

DROP TABLE IF EXISTS `models`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `models` (
  `id` int(11) NOT NULL,
  `model` varchar(255) NOT NULL DEFAULT '',
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
  `old_admin` varchar(15) DEFAULT NULL,
  `old_pass` varchar(12) DEFAULT NULL,
  `sysDescr` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`),
  UNIQUE KEY `model` (`model`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r CHECKSUM=1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `phy_types`
--

DROP TABLE IF EXISTS `phy_types`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `phy_types` (
  `phy_id` int(11) NOT NULL,
  `name` varchar(40) NOT NULL,
  `desc` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`phy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `port_status`
--

DROP TABLE IF EXISTS `port_status`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `port_status` (
  `id` tinyint(4) NOT NULL,
  `name` varchar(15) NOT NULL,
  `desc` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r CHECKSUM=1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `port_vlantag`
--

DROP TABLE IF EXISTS `port_vlantag`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
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
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `streets`
--

DROP TABLE IF EXISTS `streets`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `streets` (
  `idstreet` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  PRIMARY KEY (`idstreet`) USING BTREE,
  KEY `names` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `subnets`
--

DROP TABLE IF EXISTS `subnets`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `subnets` (
  `id` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `ip` varchar(15) NOT NULL DEFAULT '0.0.0.0',
  `netmask` varchar(15) NOT NULL DEFAULT '0.0.0.0',
  `domain` varchar(255) NOT NULL DEFAULT '',
  `nameserver1` varchar(15) NOT NULL DEFAULT '',
  `nameserver2` varchar(15) DEFAULT NULL,
  `timeserver` varchar(15) NOT NULL DEFAULT '',
  `nextserver` varchar(15) NOT NULL DEFAULT '',
  `filename` varchar(255) NOT NULL DEFAULT '',
  `leasetime` int(11) NOT NULL DEFAULT '0',
  `extra` varchar(255) DEFAULT NULL,
  `comment` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r CHECKSUM=1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `swports`
--

DROP TABLE IF EXISTS `swports`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `swports` (
  `snmp_portindex` int(11) DEFAULT NULL,
  `port_id` int(11) NOT NULL AUTO_INCREMENT,
  `link_type` tinyint(4) NOT NULL DEFAULT '20',
  `type` tinyint(4) NOT NULL DEFAULT '1',
  `sw_id` int(11) NOT NULL,
  `portpref` varchar(20) DEFAULT NULL,
  `port` int(11) NOT NULL,
  `status` tinyint(1) NOT NULL DEFAULT '1',
  `autoconf` tinyint(4) NOT NULL DEFAULT '0',
  `port_ip` varchar(15) DEFAULT NULL,
  `ds_speed` int(11) DEFAULT '-1',
  `us_speed` int(11) DEFAULT '-1',
  `mac_port` varchar(17) DEFAULT NULL,
  `info` varchar(60) DEFAULT NULL,
  `start_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `client_address` varchar(100) DEFAULT NULL,
  `portvlan` int(11) DEFAULT '-1',
  `tag` tinyint(1) NOT NULL DEFAULT '0',
  `complete_q` tinyint(4) NOT NULL DEFAULT '0',
  `login` varchar(15) DEFAULT NULL,
  `maxhwaddr` tinyint(4) NOT NULL DEFAULT '-1',
  `link_head` int(11) DEFAULT NULL,
  `phy_type` int(11) DEFAULT '1',
  `autoneg` tinyint(1) DEFAULT '1',
  `speed` int(11) DEFAULT NULL,
  `duplex` tinyint(1) DEFAULT NULL,
  `changer` varchar(15) DEFAULT NULL,
  `ip_subnet` varchar(18) DEFAULT NULL,
  PRIMARY KEY (`port_id`) USING BTREE,
  UNIQUE KEY `id` (`port_id`),
  UNIQUE KEY `AP` (`sw_id`,`portpref`,`port`,`portvlan`) USING BTREE,
  UNIQUE KEY `term_ip` (`ip_subnet`),
  KEY `mac` (`mac_port`),
  KEY `port_status` (`status`) USING BTREE,
  KEY `user` (`login`),
  KEY `link_type` (`link_type`) USING BTREE,
  KEY `head` (`link_head`),
  KEY `PHY` (`phy_type`),
  KEY `port_type` (`type`),
  CONSTRAINT `switch` FOREIGN KEY (`sw_id`) REFERENCES `hosts` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4719 DEFAULT CHARSET=koi8r CHECKSUM=1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `user_mac_port`
--

DROP TABLE IF EXISTS `user_mac_port`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `user_mac_port` (
  `login` varchar(30) CHARACTER SET latin1 NOT NULL,
  `mac` varchar(17) CHARACTER SET latin1 NOT NULL,
  `start_date` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `last_date` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `td` int(11) NOT NULL DEFAULT '0',
  `td_name` varchar(60) DEFAULT NULL,
  `idhouse` int(11) DEFAULT NULL,
  `podezd` tinyint(4) DEFAULT NULL,
  `sw_id` int(11) DEFAULT NULL,
  `port` int(11) DEFAULT NULL,
  `VLAN` int(11) DEFAULT NULL,
  `trust` tinyint(4) DEFAULT '0',
  PRIMARY KEY (`login`,`mac`,`td`),
  KEY `house` (`idhouse`),
  KEY `podezd` (`podezd`),
  KEY `switch` (`sw_id`),
  KEY `swport` (`port`),
  KEY `vlan` (`VLAN`),
  KEY `trusted` (`trust`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r CHECKSUM=1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `vlan_list`
--

DROP TABLE IF EXISTS `vlan_list`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `vlan_list` (
  `VLAN_ID` int(11) NOT NULL DEFAULT '0',
  `ZONE_ID` int(2) NOT NULL DEFAULT '-1',
  `PORT_ID` int(11) DEFAULT NULL,
  `TYPE` int(2) DEFAULT NULL,
  `LINK_TYPE` int(11) NOT NULL,
  `info` varchar(60) DEFAULT NULL,
  `Comments` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`ZONE_ID`,`VLAN_ID`) USING BTREE,
  UNIQUE KEY `PORTVLAN` (`VLAN_ID`,`ZONE_ID`,`PORT_ID`),
  KEY `Link_type` (`LINK_TYPE`),
  KEY `AP` (`PORT_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r CHECKSUM=1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `vlan_range`
--

DROP TABLE IF EXISTS `vlan_range`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `vlan_range` (
  `zone_used` int(11) NOT NULL,
  `link_type` int(11) NOT NULL,
  `vlan_min` int(11) NOT NULL,
  `vlan_max` int(11) NOT NULL,
  PRIMARY KEY (`zone_used`,`link_type`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `vlan_ranges`
--

DROP TABLE IF EXISTS `vlan_ranges`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `vlan_ranges` (
  `range_id` int(11) NOT NULL,
  `vlan_min` int(11) NOT NULL,
  `vlan_max` int(11) NOT NULL,
  `desc` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`range_id`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `vlan_types`
--

DROP TABLE IF EXISTS `vlan_types`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `vlan_types` (
  `ID` int(11) NOT NULL,
  `link_type` int(11) NOT NULL,
  `NAME` varchar(30) NOT NULL,
  `INFO` varchar(256) DEFAULT NULL,
  `start_num` int(11) NOT NULL,
  `end_num` int(11) NOT NULL,
  PRIMARY KEY (`ID`),
  KEY `NAME` (`NAME`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r CHECKSUM=1;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `vlan_usage`
--

DROP TABLE IF EXISTS `vlan_usage`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `vlan_usage` (
  `sw_id` int(11) NOT NULL,
  `vlan_id` int(11) NOT NULL,
  PRIMARY KEY (`sw_id`,`vlan_id`)
) ENGINE=InnoDB DEFAULT CHARSET=koi8r;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `vlan_zones`
--

DROP TABLE IF EXISTS `vlan_zones`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `vlan_zones` (
  `zone_id` tinyint(4) NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL,
  `desc` varchar(100) CHARACTER SET latin1 NOT NULL,
  PRIMARY KEY (`zone_id`)
) ENGINE=InnoDB AUTO_INCREMENT=18446744073709551615 DEFAULT CHARSET=koi8r;
SET character_set_client = @saved_cs_client;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2009-09-17  9:18:13
