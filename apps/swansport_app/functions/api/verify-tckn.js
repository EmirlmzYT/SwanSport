import { createVerifyTcknHandler, withIdentityCors } from '../../functions_helpers/identity-verification.js';

export const onRequestPost = withIdentityCors(createVerifyTcknHandler());
export const onRequestGet = withIdentityCors(createVerifyTcknHandler());
export const onRequestOptions = withIdentityCors(createVerifyTcknHandler());
