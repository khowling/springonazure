import React, { Component } from 'react';
import './style/style.css';
import './style/lumino.css';



class App extends Component {

  constructor(props) {
    super(props);
    this.state = {people: []}
    this.input = React.createRef();
  }
  

  componentDidMount() {
    this.get()
  }

  add() {
    this._fetchit('POST','/api/people', JSON.stringify({firstName: this.input.current.value})).then(succ => {
      console.log (`created success : ${JSON.stringify(succ)}`)
      this.input.current.value = ""
      this.get()
    }, err => {
      this.setState({error: `POST ${err}`})
    })
  }

  get() {
    this._fetchit('GET','/api/people').then(succ => {
      console.log (`got list success : ${JSON.stringify(succ)}`)
      this.setState({ error: null, people: succ._embedded.people});
    }, err => {
      this.setState({error: `GET ${err}`})
    })
  }

  del(p) {
    console.log (`del ${p}`)
    this._fetchit('DELETE',p).then(succ => {
      console.log (`delete success : ${JSON.stringify(succ)}`)
      this.get()
    }, err => {
      this.setState({error: `DELETE ${err}`})
    })
  }


  _fetchit(type, url, body = null) {
    return new Promise((resolve, reject) => {
      let opts = {
        crossDomain:true,
        method: type,
      }
      if (body) {
        opts.body = body
        opts.headers = {
          'content-type': 'application/json'
        }
      }

      fetch(url, opts).then((r) => {
        console.log (r.status)
        if (!r.ok) {
          console.log (`non 200 err : ${r.status}`)
          return reject(r.status)
        } else {
          if (r.status == 204 && type == 'DELETE') {
            return resolve();
          } else {
            r.json().then(rjson => {
              if (rjson) {
                return resolve(rjson)
              } else {
                return reject("no output")
              }
            })
          }          
        }
        }, err => {
          console.log (`err : ${err}`)
          return reject(err)
        })
      })
  }



  render() {
    return (
      <div className="container">
        <div className="row">
          <div className="col-lg-12">
            <h1 className="page-header">People Demo</h1>
            { this.state.error && 
            <div className="alert bg-danger" role="alert">
              <em className="fa fa-lg fa-warning">&nbsp;</em>Backend error : {this.state.error} 
              <a href="#" className="pull-right"><em className="fa fa-lg fa-close"></em></a></div>
            }
          </div>
        </div>

        <div className="row">
          <div className="col-md-6">
            <div className="panel panel-primary">

              <div className="panel-heading">
                People List
                <ul className="pull-right panel-settings panel-button-tab-right">
                  <li className="dropdown">
                    <em className="fa fa-cogs"></em>
                  </li>
                </ul>
                <span className="pull-right clickable panel-toggle panel-button-tab-left"><em className="fa fa-toggle-up"></em></span>
              </div>
              
              <div className="panel-body">
                <ul className="todo-list">

                  { this.state.people.map((p,i) => 

                    <li key={i} className="todo-list-item">
                    <div className="checkbox">
                      <input type="checkbox"/>
                      <label >{p.firstName}</label>
                    </div>
                    <div className="pull-right action-buttons"><a onClick={this.del.bind(this,p._links.self.href)}  className="trash">
                      <em className="fa fa-trash"></em>
                    </a></div>
                    </li>
                  )}
                </ul>
              </div>
              <div className="panel-footer">
                <div className="input-group">
                  <input type="text" className="form-control input-md" placeholder="First name" ref={this.input}/><span className="input-group-btn">
                    <button className="btn btn-primary btn-md" onClick={this.add.bind(this)} >Add</button>
                </span></div>
              </div>
            </div>
          </div>
        </div>
      </div>

    );
  }
}

export default App;
