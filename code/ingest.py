import happybase
import time
import hashlib
import random

# Configuration
HBASE_HOST = 'localhost'
TABLE_NAME = 'webTable'

def get_rowkey(url):
    """Generate salted reversed URL rowkey using a salt from '0' to 'f'."""
    hex_digits = '0123456789abcdef'
    h = int(hashlib.md5(url.encode()).hexdigest(), 16)
    salt = hex_digits[h % 16]  # single hex digit salt from 0 to f
    domain = '.'.join(reversed(url.split('://')[1].split('/')[0].split('.')))
    path = '/' + '/'.join(url.split('/')[3:]) or '/'
    return f"{salt}!{domain}{path}"

def create_connection():
    """Create HBase connection"""
    connection = happybase.Connection(HBASE_HOST)
    connection.open()
    return connection

def ingest_sample_data(table):
    # Homepage with multiple versions on 'content'
    table.put(
        b'a0!com.example.www/',
        {
            b'content:html': b'<html><h1>Welcome</h1><a href="/about">About Us</a></html>',  # content family
            b'content:text': b'Welcome to our site. About Us.',
            b'meta:fetch_time': b'1717020000000',  # meta family
            b'meta:status': b'200',
            b'meta:content_type': b'text/html',
            b'outlinks:com.example.www/about': b'About Us'  # outlinks family
        }
    )

    # About Page
    table.put(
        b'b0!com.example.www/about',
        {
            b'content:html': b'<html><h2>About</h2><p>Our company info</p></html>',  # content
            b'meta:fetch_time': b'1717020001000',  # meta
            b'inlinks:com.example.www/': b'Home'  # inlinks
        }
    )

    # External Blog
    table.put(
        b'c0!net.blog.tech/123',
        {
            b'content:html': b'<html><p>Check out <a href="https://www.example.com">Example Inc</a></p></html>',  # content
            b'outlinks:com.example.www/': b'Example Inc'  # outlinks
        }
    )
    # Backlink entry in inlinks family
    table.put(
        b'a0!com.example.www/',
        {b'inlinks:net.blog.tech/123': b'Example Inc'}  # inlinks
    )

def generate_website_data(table, domain, num_pages=5):
    """Generate realistic website data"""
    base_url = f"https://{domain}"
    pages = ['/'] + [f'/page-{i}' for i in range(1, num_pages)]
    
    # Create main pages
    for idx, path in enumerate(pages):
        url = base_url + path
        rowkey = get_rowkey(url)
        
        data = {
            b'content:html': f'<html><h1>{domain} {path}</h1></html>'.encode(),
            b'content:text': f'Welcome to {domain} {path}'.encode(),
            b'meta:fetch_time': str(int(time.time() * 1000)).encode(),
            b'meta:status': b'200',
            b'meta:content_type': b'text/html'
        }
        
        # Create links between pages
        if idx > 0:
            prev_page = pages[idx-1]
            data[b'outlinks:' + get_rowkey(base_url + prev_page).encode()] = b'Previous Page'
            table.put(
                get_rowkey(base_url + prev_page).encode(),
                {b'outlinks:' + rowkey.encode(): b'Next Page'}
            )
        
        table.put(rowkey.encode(), data)

def main():
    connection = create_connection()
    table = connection.table(TABLE_NAME)
    
    # Ingest original sample data
    ingest_sample_data(table)
    
    # Generate data for popular websites
    websites = [
        'www.google.com',
        'www.youtube.com',
        'www.facebook.com',
        'www.amazon.com',
        'www.wikipedia.org'
    ]
    
    for domain in websites:
        generate_website_data(table, domain, num_pages=random.randint(3, 8))
    
    connection.close()

if __name__ == '__main__':
    main()
