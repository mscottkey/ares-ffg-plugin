import Component from '@glimmer/component';

export default class FfgChargenComponent extends Component {
  // just convenience getters so the template is cleaner
  get char() {
    return this.args.char || {};
  }

  get cgInfo() {
    return this.args.cg_info || {};
  }
}
