from flask import Flask, render_template, request, url_for, redirect, abort, session
from pygments import highlight
from pygments.lexers import get_lexer_by_name,PerlLexer
from pygments.formatters import HtmlFormatter
import MySQLdb
import json
import yaml

app = Flask('psi')
app.debug = True
app.secret_key = 'super secret'
config = yaml.load(open("config.yaml", "r"))

def get_db():
    con = MySQLdb.connect(host = config['db_host'], db = config['db_name'], user = config['db_user'], passwd = config['db_pass']);
    return con.cursor()
    
@app.route('/login', methods=['GET'])
def get_login():
    return render_template('login.html');

@app.route('/login', methods=['POST'])
def post_login():
    if request.form['username'] == 'super' and request.form['password'] == 'secret':
        session['username'] = request.form['username']
        return redirect(url_for('home'))
    else:
        return 'wrong username or password', 401

@app.route('/')
def home():
    if 'username' not in session:
        return redirect(url_for('get_login'))

    return render_template('home.html')

@app.route('/search')
def search():
    if 'username' not in session:
        return redirect(url_for('get_login'))
        
    text = request.args.get('text')
    db = get_db();
    db.execute("select p.name from packages p join tags t on t.package_id = p.id where t.name like %s order by p.name", (text + '%',))
    packages = [o[0] for o in db.fetchall()]
    
    return json.dumps(packages)

@app.route('/properties')
def properties():
    if 'username' not in session:
        return redirect(url_for('get_login'))

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
    if 'username' not in session:
        return redirect(url_for('get_login'))

    package = request.args.get('package')
    db = get_db()
    db.execute("select source from packages where name = %s", (package,))
    source = db.fetchone()[0]
    formatter = HtmlFormatter(noclasses=True)
    pretty = highlight(source, PerlLexer(), formatter)
    return json.dumps(pretty)

    

app.run(config['ip'])

