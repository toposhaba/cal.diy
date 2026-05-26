public with sharing class SchedulingException extends Exception {
    private String errorCode;

    public SchedulingException(String errorCode, String message) {
        this(message);
        this.errorCode = errorCode;
    }

    public String getErrorCode() {
        return this.errorCode;
    }
}
