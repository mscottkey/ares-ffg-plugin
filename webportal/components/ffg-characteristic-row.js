import Component from '@glimmer/component';
import { action } from '@ember/object';
import { set } from '@ember/object';

export default class FfgCharacteristicRowComponent extends Component {
  get maxRating() {
    // from @maxRating or default to 5
    return this.args.maxRating ?? 5;
  }

  @action
  increase() {
    let c = this.args.charac;
    if (!c) return;

    let current = c.rating || 0;
    if (current >= this.maxRating) return;

    set(c, 'rating', current + 1);

    if (this.args.updated) {
      this.args.updated();
    }
  }

  @action
  decrease() {
    let c = this.args.charac;
    if (!c) return;

    let current = c.rating || 0;
    if (current <= 0) return;

    set(c, 'rating', current - 1);

    if (this.args.updated) {
      this.args.updated();
    }
  }
}
