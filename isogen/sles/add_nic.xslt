<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:default="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns" exclude-result-prefixes="default">
  <xsl:output method="xml" encoding="UTF-8" omit-xml-declaration="no" indent="yes"/>
  <xsl:param name="nic_name" as="xs:string"/>
  <xsl:param name="nic_descr" as="xs:string"/>
  <xsl:template match="@*|node()">
      <xsl:copy>
          <xsl:apply-templates select="@*|node()"/>
      </xsl:copy>
  </xsl:template>
  <xsl:template match="/default:profile/default:general/default:ask-list/default:ask[default:dialog='0']/default:selection">
    <xsl:copy>
        <xsl:apply-templates select="@*|*"/>
        <entry xmlns="http://www.suse.com/1.0/yast2ns">
            <value><xsl:value-of select="$nic_name"/></value>
            <label><xsl:value-of select="$nic_descr"/></label>
        </entry>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
