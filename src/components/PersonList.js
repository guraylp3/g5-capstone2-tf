import React from 'react';
import axios from 'axios';

export default class PersonList extends React.Component {
  state = {
    persons: []
  }

  componentDidMount() {
    axios.get(`https://igqma0tvx3.execute-api.us-west-2.amazonaws.com/prod/get-person`)
      .then(res => {
        const persons = res.data.body;
        this.setState({ persons });
      })
  }

  render() {
    return (
      <ul>
        {
          this.state.persons
            .map(person =>
              <li key={person.id}>{person.id}{person.name}</li>
            )
        }
      </ul>
    )
  }
}