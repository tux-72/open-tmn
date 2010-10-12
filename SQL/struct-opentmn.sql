-- MySQL dump 10.13  Distrib 5.1.50, for portbld-freebsd7.3 (amd64)
--
-- Host: localhost    Database: myisp_net
-- ------------------------------------------------------
-- Server version	5.1.50

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
-- Current Database: `myisp_net`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `myisp_net` /*!40100 DEFAULT CHARACTER SET latin1 */;

USE `myisp_net`;

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
) ENGINE=InnoDB AUTO_INCREMENT=823 DEFAULT CHARSET=koi8r CHECKSUM=1;
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
) ENGINE=InnoDB AUTO_INCREMENT=357 DEFAULT CHARSET=koi8r CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;

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
) ENGINE=InnoDB AUTO_INCREMENT=191987 DEFAULT CHARSET=koi8r;
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
) ENGINE=InnoDB AUTO_INCREMENT=5465 DEFAULT CHARSET=koi8r CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;

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
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2010-10-08 11:57:40
