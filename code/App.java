import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.hbase.*;
import org.apache.hadoop.hbase.client.*;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Arrays;
import java.util.List;
import java.util.Random;

public class App {

    private static final String TABLE_NAME = "webTable";

    private static Connection connection;

    public static void main(String[] args) throws Exception {
        Configuration config = HBaseConfiguration.create();
        // configure HBase connection parameters if needed, e.g. Zookeeper quorum
        connection = ConnectionFactory.createConnection(config);

        createTable();

        Table table = connection.getTable(TableName.valueOf(TABLE_NAME));

        // Insert sample data
        ingestSampleData(table);

        // Generate and insert website data
        List<String> websites = Arrays.asList(
                "www.google.com",
                "www.youtube.com",
                "www.facebook.com",
                "www.amazon.com",
                "www.wikipedia.org"
        );
        Random random = new Random();

        for (String domain : websites) {
            generateWebsiteData(table, domain, 3 + random.nextInt(6));
        }

        table.close();
        connection.close();
    }

    private static void createTable() throws IOException {
        Admin admin = connection.getAdmin();
        TableName tableName = TableName.valueOf(TABLE_NAME);

        if (admin.tableExists(tableName)) {
            admin.disableTable(tableName);
            admin.deleteTable(tableName);
        }

        HTableDescriptor tableDescriptor = new HTableDescriptor(tableName);

        // content column family
        HColumnDescriptor contentCF = new HColumnDescriptor("content");
        contentCF.setBloomFilterType(BloomType.ROW);
        contentCF.setMaxVersions(1);
        contentCF.setBlockCacheEnabled(true);
        contentCF.setCompressionType(Compression.Algorithm.NONE);
        contentCF.setBlocksize(65536);
        contentCF.setInMemory(true);

        // meta column family
        HColumnDescriptor metaCF = new HColumnDescriptor("meta");
        metaCF.setBloomFilterType(BloomType.ROW);
        metaCF.setMaxVersions(1);
        metaCF.setBlockCacheEnabled(true);
        metaCF.setCompressionType(Compression.Algorithm.NONE);
        metaCF.setBlocksize(16384);

        // outlinks column family
        HColumnDescriptor outlinksCF = new HColumnDescriptor("outlinks");
        outlinksCF.setBloomFilterType(BloomType.ROWCOL);
        outlinksCF.setMaxVersions(1);
        outlinksCF.setBlockCacheEnabled(true);
        outlinksCF.setCompressionType(Compression.Algorithm.NONE);
        outlinksCF.setBlocksize(32768);

        // inlinks column family
        HColumnDescriptor inlinksCF = new HColumnDescriptor("inlinks");
        inlinksCF.setBloomFilterType(BloomType.ROWCOL);
        inlinksCF.setMaxVersions(1);
        inlinksCF.setBlockCacheEnabled(true);
        inlinksCF.setCompressionType(Compression.Algorithm.NONE);
        inlinksCF.setBlocksize(32768);

        tableDescriptor.addFamily(contentCF);
        tableDescriptor.addFamily(metaCF);
        tableDescriptor.addFamily(outlinksCF);
        tableDescriptor.addFamily(inlinksCF);

        admin.createTable(tableDescriptor);
        admin.close();

        System.out.println("Table " + TABLE_NAME + " created.");
    }

    private static String getRowKey(String url) throws NoSuchAlgorithmException {
        // Generate 2-byte salt from MD5 hash of URL
        MessageDigest md = MessageDigest.getInstance("MD5");
        byte[] digest = md.digest(url.getBytes(StandardCharsets.UTF_8));
        StringBuilder saltBuilder = new StringBuilder();
        for (int i = 0; i < 2; i++) {
            saltBuilder.append(String.format("%02x", digest[i]));
        }
        String salt = saltBuilder.toString();

        // Reverse domain components
        String withoutProtocol = url.split("://")[1];
        String domain = withoutProtocol.split("/")[0];
        String[] domainParts = domain.split("\\.");
        StringBuilder reversedDomain = new StringBuilder();
        for (int i = domainParts.length - 1; i >= 0; i--) {
            reversedDomain.append(domainParts[i]);
            if (i != 0) reversedDomain.append(".");
        }

        // Path part
        String[] pathParts = withoutProtocol.split("/", 2);
        String path = "/";
        if (pathParts.length > 1) {
            path += pathParts[1];
        }

        return salt + "!" + reversedDomain.toString() + path;
    }

    private static void ingestSampleData(Table table) throws IOException, NoSuchAlgorithmException {
        Put homepage = new Put("a0!com.example.www/".getBytes(StandardCharsets.UTF_8));
        homepage.addColumn("content".getBytes(), "html".getBytes(), "<html><h1>Welcome</h1><a href=\"/about\">About Us</a></html>".getBytes());
        homepage.addColumn("content".getBytes(), "text".getBytes(), "Welcome to our site. About Us.".getBytes());
        homepage.addColumn("meta".getBytes(), "fetch_time".getBytes(), "1717020000000".getBytes());
        homepage.addColumn("meta".getBytes(), "status".getBytes(), "200".getBytes());
        homepage.addColumn("meta".getBytes(), "content_type".getBytes(), "text/html".getBytes());
        homepage.addColumn("outlinks".getBytes(), "com.example.www/about".getBytes(), "About Us".getBytes());
        table.put(homepage);

        Put aboutPage = new Put("b0!com.example.www/about".getBytes(StandardCharsets.UTF_8));
        aboutPage.addColumn("content".getBytes(), "html".getBytes(), "<html><h2>About</h2><p>Our company info</p></html>".getBytes());
        aboutPage.addColumn("meta".getBytes(), "fetch_time".getBytes(), "1717020001000".getBytes());
        aboutPage.addColumn("inlinks".getBytes(), "com.example.www/".getBytes(), "Home".getBytes());
        table.put(aboutPage);

        Put externalBlog = new Put("c0!net.blog.tech/123".getBytes(StandardCharsets.UTF_8));
        externalBlog.addColumn("content".getBytes(), "html".getBytes(), "<html><p>Check out <a href=\"https://www.example.com\">Example Inc</a></p></html>".getBytes());
        externalBlog.addColumn("outlinks".getBytes(), "com.example.www/".getBytes(), "Example Inc".getBytes());
        table.put(externalBlog);

        Put backLink = new Put("a0!com.example.www/".getBytes(StandardCharsets.UTF_8));
        backLink.addColumn("inlinks".getBytes(), "net.blog.tech/123".getBytes(), "Example Inc".getBytes());
        table.put(backLink);
    }

    private static void generateWebsiteData(Table table, String domain, int numPages) throws IOException, NoSuchAlgorithmException {
        String baseUrl = "https://" + domain;
        String[] pages = new String[numPages];
        pages[0] = "/";
        for (int i = 1; i < numPages; i++) {
            pages[i] = "/page-" + i;
        }

        for (int i = 0; i < numPages; i++) {
            String url = baseUrl + pages[i];
            String rowkey = getRowKey(url);
            Put put = new Put(rowkey.getBytes(StandardCharsets.UTF_8));

            put.addColumn("content".getBytes(), "html".getBytes(), ("<html><h1>" + domain + " " + pages[i] + "</h1></html>").getBytes());
            put.addColumn("content".getBytes(), "text".getBytes(), ("Welcome to " + domain + " " + pages[i]).getBytes());
            put.addColumn("meta".getBytes(), "fetch_time".getBytes(), String.valueOf(System.currentTimeMillis()).getBytes());
            put.addColumn("meta".getBytes(), "status".getBytes(), "200".getBytes());
            put.addColumn("meta".getBytes(), "content_type".getBytes(), "text/html".getBytes());

            if (i > 0) {
                // add outlink to previous page
                String prevUrl = baseUrl + pages[i - 1];
                String prevRowkey = getRowKey(prevUrl);
                put.addColumn("outlinks".getBytes(), prevRowkey.getBytes(), "Previous Page".getBytes());

                // add next link to previous page row
                Put prevPut = new Put(prevRowkey.getBytes());
                prevPut.addColumn("outlinks".getBytes(), rowkey.getBytes(), "Next Page".getBytes());
                table.put(prevPut);
            }

            table.put(put);
        }
    }
}
