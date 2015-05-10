from flask import Flask, render_template, request
from pygments import highlight
from pygments.lexers import get_lexer_by_name,PerlLexer
from pygments.formatters import HtmlFormatter
import MySQLdb
import json

app = Flask('psi')
app.config.from_object('config')

def get_db():
    con = MySQLdb.connect(
        'host' = app.config['DB_HOST'], 
        'db' = app.config['DB_NAME'],
        'user' = app.config['DB_USER'], 
        'passwd' = app.config['DB_PASS']
    );
    return con.cursor()
    
@app.route('/hello')
def hello():
    return "hello, world"

@app.route('/')
def home():
    return render_template('home.html')

@app.route('/search')
def search():
    text = request.args.get('text')
    db = get_db();
    db.execute("select p.name from packages p join tags t on t.package_id = p.id where t.name like %s order by p.name", (text + '%',))
    packages = [o[0] for o in db.fetchall()]
    
    return json.dumps(packages)

@app.route('/properties')
def properties():
    package = request.args.get('package')
    db = get_db()
    db.execute("select p.name, p.type, p.id from properties p join packages pack on pack.id = p.package_id where pack.name = %s and p.name not like '\_%%' order by p.name", (package,))
    result = []
    for (name, type, id) in db.fetchall():
        db.execute("select name, type from params where property_id = %s", (id,))
        params = []
        for (subname, subtype) in db.fetchall():
            params.append({ 'subname': subname, 'subtype': subtype })

        result.append({ 'name': name, 'type': type, 'params': params });

    
    return json.dumps(result);

@app.route("/source")
def get_source():
    package = request.args.get('package')
    db = get_db()
    db.execute("select source from packages where name = %s", (package,))
    source = db.fetchone()[0]
    formatter = HtmlFormatter(noclasses=True)
    pretty = highlight(source, PerlLexer(), formatter)
    return json.dumps(pretty)

    

app.run(app.config['IP'])

