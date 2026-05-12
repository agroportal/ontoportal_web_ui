import { Controller } from '@hotwired/stimulus'
import { getYasgui } from '../mixins/useYasgui'

export default class extends Controller {
  static values = {
    proxy: String,
    apikey: String,
    graph: String,
    sampleQueries: Array,
    aiEnabled: Boolean,
    aiGenerateUrl: String
  }

  static targets = ['yasgui', 'aiPanel', 'aiPrompt', 'aiButton', 'aiStatus']

  connect() {
    localStorage.removeItem('yagui__config');
    const yasguiHost = this.hasYasguiTarget ? this.yasguiTarget : this.element;
    this.yasgui = getYasgui(yasguiHost,
      {
        copyEndpointOnNewTab: true,
        requestConfig: {
          endpoint: this.#proxyUrl(),
          acceptHeaderGraph: false,
          acceptHeaderUpdate: false,
        }
      })

    this.#addExampleTabs()

    this.#setupSaveButton()

  }

  aiGenerate(event) {
    if (event && event.type === 'keydown') {
      if (event.shiftKey) return;
      event.preventDefault();
    }

    if (!this.aiEnabledValue || !this.aiGenerateUrlValue) return;
    if (!this.hasAiPromptTarget) return;

    const prompt = this.aiPromptTarget.value.trim();
    if (!prompt) {
      this.#setAiStatus('Please enter a prompt.', 'error');
      return;
    }

    const tab = this.yasgui.getTab();
    const currentQuery = tab ? tab.getQuery() : '';
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');

    this.#setAiBusy(true);
    this.#setAiStatus('Generating SPARQL query…', 'info');

    const payload = {
      prompt,
      graph: this.graphValue || null,
      current_query: currentQuery || null
    };

    fetch(this.aiGenerateUrlValue, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': csrfToken || ''
      },
      body: JSON.stringify(payload)
    })
      .then(async (response) => {
        const data = await response.json().catch(() => ({}));
        if (!response.ok) {
          throw new Error(data.error || `Request failed (${response.status})`);
        }
        return data;
      })
      .then((data) => {
        if (!data.query) throw new Error('Empty response from AI service');
        this.#applyGeneratedQuery(data.query);
        this.#setAiStatus('Query generated. Review and run it.', 'success');
      })
      .catch((err) => {
        console.error('AI SPARQL generation failed:', err);
        this.#setAiStatus(err.message || 'Failed to generate query', 'error');
      })
      .finally(() => {
        this.#setAiBusy(false);
      });
  }

  #applyGeneratedQuery(query) {
    const trimmed = query.trim();
    let tab = this.yasgui.getTab();
    if (!tab) {
      tab = this.yasgui.addTab(true, { name: 'AI query' });
    }
    tab.setQuery(trimmed);
  }

  #setAiBusy(busy) {
    if (this.hasAiButtonTarget) {
      this.aiButtonTarget.disabled = busy;
      this.aiButtonTarget.classList.toggle('is-loading', busy);
    }
    if (this.hasAiPromptTarget) {
      this.aiPromptTarget.disabled = busy;
    }
  }

  #setAiStatus(message, type) {
    if (!this.hasAiStatusTarget) return;
    this.aiStatusTarget.textContent = message || '';
    this.aiStatusTarget.dataset.state = type || '';
  }

  #proxyUrl() {
    return `${this.proxyValue}?default-graph-uri=${this.graphValue}&apikey=${this.apikeyValue}`
  }

  #addExampleTabs() {
    const defaultQuery = `# Add a description of your sample Query here

PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT * WHERE {
  ?sub ?pred ?obj .
} LIMIT 10`;

    setTimeout(() => {
      let queries = this.sampleQueriesValue;
      // Strip padding comments added to preserve order
      queries = queries.map(query => {
        // Remove trailing padding comment (e.g., "# " followed by spaces)
        return query.replace(/\n#\s*$/, '').trimEnd();
      });

      this.yasgui.getTab().close()
      if (queries.length === 0) {
        const tab = this.yasgui.addTab(true, { name: 'Sample query' }, { atIndex: 0 });
        tab.setQuery(defaultQuery);
      } else {
        for (let i = queries.length - 1; i >= 0; i--) {
          const tab = this.yasgui.addTab(true, { name: `Sample query ${i + 1}` }, { atIndex: 0 });
          tab.setQuery(queries[i]);
        }
      }
    }, 50);
  }

  #setupSaveButton() {
    const saveButton = document.getElementById('queries-save-button');
    if (saveButton) {
      saveButton.addEventListener('click', (e) => {
        e.preventDefault();
        this.#saveCurrentQuery();
        this.#showMessage('Queries saved successfully', 'success');
      });
    }
  }

  #saveCurrentQuery() {
    const tabElements = document.querySelectorAll('.edit_sparql_container [role="tab"]');
    const queries = [];

    tabElements.forEach((tabElement, index) => {
      const tab = this.yasgui.getTab(`${tabElement.id.split('-')[1]}`);
      const query = tab.getQuery();
      if (query) {
        queries.push(query);
      }
    });

    if (queries.length > 0) {
      // Pad all queries to the same length to prevent backend sorting by length
      const maxLength = Math.max(...queries.map(q => q.length));
      const paddedQueries = queries.map(query => {
        // Add padding as a comment at the end to reach maxLength
        const paddingNeeded = maxLength - query.length;
        if (paddingNeeded > 0) {
          return query + '\n# ' + ' '.repeat(paddingNeeded);
        }
        return query;
      });

      const ontologyId = this.#extractOntologyId();
      this.#sendSaveRequest(paddedQueries, ontologyId);
    }
  }



  #extractOntologyId() {
    const graph = this.graphValue;
    if (graph) {
      const match = graph.match(/\/ontologies\/([^\/]+)\/submissions\/([^\/]+)/);
      if (match) {
        return `/ontologies/${match[1]}/submissions/${match[2]}`;
      }
    }
    return null;
  }

  #sendSaveRequest(queries, ontologyId) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
    const formData = new FormData();
    formData.append('_method', 'patch');

    const queryKey = ontologyId ? 'ontology[sampleQueries][]' : 'config[sampleQueries][]';
    if (Array.isArray(queries)) {
      queries.forEach(query => {
        formData.append(queryKey, query);
      });
    } else {
      formData.append(queryKey, queries);
    }
    const endpoint = ontologyId ? `${ontologyId}` : '/admin/catalog_configuration'
    const graph = this.graphValue;

    const match = graph.match(/\/ontologies\/([^\/]+)\/submissions\/([^\/]+)/);

    if (ontologyId) {
      formData.append('ontology_id', match[1]);
    }

    fetch(endpoint, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': csrfToken
      },
      body: formData
    })
      .then(response => {
        if (response.ok) {
          console.log('Queries saved successfully');
        } else {
          console.error('Failed to save queries');
        }
      })
      .catch(error => {
        console.error('Error saving queries:', error);
      });
  }


  #showMessage(message, type) {
    const notificationContainer = document.querySelector('.sparql-notifications');
    const messageDiv = document.createElement('div');
    messageDiv.textContent = message;
    messageDiv.style.padding = '10px 20px';
    messageDiv.style.borderRadius = '4px';
    messageDiv.style.backgroundColor = type === 'success' ? '#d4edda' : '#f8d7da';
    messageDiv.style.color = type === 'success' ? '#155724' : '#721c24';
    messageDiv.style.border = type === 'success' ? '1px solid #c3e6cb' : '1px solid #f5c6cb';
    messageDiv.style.marginBottom = '10px'

    if (notificationContainer) {
      notificationContainer.appendChild(messageDiv);

      setTimeout(() => {
        if (notificationContainer.contains(messageDiv)) {
          notificationContainer.removeChild(messageDiv);
        }
      }, 3000);
    } else {
      messageDiv.style.position = 'fixed';
      messageDiv.style.top = '20px';
      messageDiv.style.right = '20px';
      messageDiv.style.zIndex = '1000';

      document.body.appendChild(messageDiv);

      setTimeout(() => {
        if (document.body.contains(messageDiv)) {
          document.body.removeChild(messageDiv);
        }
      }, 3000);
    }
  }
}